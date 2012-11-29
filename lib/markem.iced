utils=require 'bal-util'
mkdirp=require 'mkdirp'
path=require 'path'
jade=require 'jade'
fs=require 'fs'
marked=require 'marked'
childprocess=require 'child_process'

module.exports=markem=
  version:  '0.0.3'
  options: null
  run: (options,cb)->

    this.options=options
    this.tmp=options.out||'markem.out'
    self=this
    # serving skeletons
    await fs.exists path.join('markem.conf','layout.jade'),defer exists
    if !exists
      await fs.readdir path.join(__dirname,'..','skeletons'),defer err,layouts
      console.log "Seems like you havn't got a layout for your site. You can choose one skeleton from below."
      for layout,i in layouts
        console.log "#{i+1}. #{layout}"
      process.stdout.write "Which one do you want to use: "
      process.stdin.setEncoding 'utf8'
      process.stdin.resume()
      await process.stdin.on 'data',defer input
      layout=null
      try
        layout=layouts[Number(input)-1]
      catch e
        console.log e.message
      process.stdin.pause()
      if !layout?
        process.exit 1
        return
      await mkdirp 'markem.conf',defer err
      await utils.cpdir path.join(__dirname,'..','skeletons',layout),'markem.conf',defer err
      console.log "'markem.conf' created."

    # prepare template
    await fs.readFile path.join('markem.conf','layout.jade'),'utf8',defer err,layout
    try
      layout=jade.compile layout,
        filename:path.join('markem.conf','layout.jade')
    catch e
      console.error e
      process.exit 1
      return

    if !options.out?
      # detect Git remote
      await this._git "remote -v",null,defer err,out
      fetch=out.match(/origin\s*([^\s]*)\s*\(fetch\)/)[1]
      console.log "git url: #{fetch}"

      # detect GithubPage branch
      branch='gh-pages'
      if fetch.match /\.github\.com/
        branch='master'

      # make sure users dont put documents in their GithubPage branch
      await this._git "status",null,defer err,out
      curBranch=out.match(/on\s*branch\s*([^\s]*)/i)[1]
      if curBranch==branch
        console.err "You are in target branch '#{branch}'. Put your documents in another branch!!!"

      # get current gh-pages (make sure git clone done well)
      await mkdirp self.tmp,defer err
      await utils.rmdirDeep self.tmp,defer err
      console.log "Cloning branch '#{branch}' into '#{self.tmp}'"
      await this._git "clone --branch #{branch} #{fetch} #{self.tmp}",null,defer err,out

      # make sure GithubPage branch exists
      await this._git "status",self.tmp,defer err,out
      if !out.match branch
        console.log "Branch '#{branch}' does not exists. creating..."
        await this._git "branch #{branch}",self.tmp,defer err
      await this._git "checkout #{branch}",self.tmp,defer err
    else
      await mkdirp self.tmp,defer err


    # generate content
    console.log "Generating content..."
    await this._generate layout,defer()

    if !options.out?
      # commit&push back to Github
      await this._git "add --all",self.tmp,defer err
      await this._git "commit -m 'compiled by markem'",self.tmp,defer err,out
      console.log out
      console.log "Pushing back into origin..."
      await this._git "push origin #{branch}",self.tmp,defer err




      await utils.rmdirDeep self.tmp,defer err
      console.log "Done."

  # calling git commands
  # params:
  #     command: git sub-commands and options
  #     workTree: git working copy location, default to null
  # callback:
  #     cb(err,stdout,stderr)
  _git:(command,workTree,cb)->
    if workTree?
      command="git --work-tree #{workTree} --git-dir #{path.join workTree,'.git'} #{command}"
    else
      command="git #{command}"
    await childprocess.exec command,defer err,stdout,stderr
    if this.options.verbose
      console.log "> #{command}"
      if stderr?&&stderr.trim().length
        console.error stderr
      if stdout?&&stdout.trim().length
        console.log stdout
    if err?&&stderr?&&stderr.trim().length
      console.error stderr
      utils.rmdirDeep 'markem.out',->
      process.exit 1
      return
    cb(err,stdout,stderr)
  _generate: (layout,cb)->
    self=this
    utils.scandir
      path: self.tmp,
      readFiles:false
      ignoreHiddenFiles: true
      recurse:false
      next:(err,list)->
        for file,type of list
          file=path.join self.tmp,file
          if type=='dir'
            await utils.rmdirDeep file,defer err
          else
            await utils.unlink file,defer err
        await utils.cpdir 'markem.conf',self.tmp,defer err
        await utils.unlink path.join(self.tmp,'layout.jade'),defer err
        utils.scandir
          path: '.'
          readFiles: false
          ignoreHiddenFiles: true
          next: (err,list) ->
            globals={}
            documents={}

            # initialize some basic stuff
            for relative,type of list
              if type=='file'&&!relative.match /node_modules/
                target=null
                if relative.match /\.markdown$/
                  target=path.join self.tmp,relative.replace /\.markdown$/,'.html'
                if relative.match /\.md$/
                  target=path.join self.tmp,relative.replace /\.md$/,'.html'
                if relative.match new RegExp("readme\\.md$",'i')
                  target=path.join self.tmp,relative.replace new RegExp("[^#{path.sep}]*$"),'index.html'
                if target?
                  document=
                    dirs:[]
                    files:[]
                    pathSource:'/'+relative
                    pathFile:'/'+path.relative(self.tmp,target)
                    target:target
                    globals:globals
                  document.path=document.pathFile.replace(/\/index\.html$/,'/')
                  document.root=path.relative document.path.replace(/\/[^\/]*$/,'/'),'\/'
                  if !document.root.length
                    document.root='.'
                  documents[document.path]=document
                  await fs.readFile relative,'utf8',defer err,document.source


            # build relationships,content,title between documents
            for p,document of documents
              document.content=marked document.source
              document.title=(document.content.match(/<h1>([^<]*)<\/h1>/m)||[null,'untitled'])[1] 
              if p=='/'
                globals.root=document
              if p.match /\/$/
                document.parent=documents[p.replace(/[^\/]*\/$/,'')]
                document.type='dir'
              else
                document.parent=documents[p.replace(/[^\/]+$/,'')]
                document.type='file'
              if document.parent?
                if document.type=='dir'
                  document.parent.dirs.push document
                else
                  document.parent.files.push document

            try
              markemConf=require path.join process.cwd(),'markem.conf'
            catch e
            if markemConf? and markemConf.preRender?
              await markemConf.preRender globals,defer err

            # render each documents
            for p,document of documents
              if markem.options.verbose
                console.log "rendering #{document.target}"
              await mkdirp path.dirname(document.target),defer err
              try
                document.output=layout document
              catch e
                console.error e
                utils.rmdirDeep self.tmp,->
                process.exit 1
                return
              await fs.writeFile document.target,document.output,'utf8',defer err
            cb()