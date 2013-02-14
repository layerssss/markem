utils=require 'bal-util'
mkdirp=require 'mkdirp'
path=require 'path'
jade=require 'jade'
fs=require 'fs'
marked=require 'marked'
childprocess=require 'child_process'

module.exports = class markem
  @version:  require('../package.json').version
  @options: null
  @run: (options,cb)->

    @options = options
    @tmp = options.out||'markem.out'
    @source = options.source||'.'

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
      await @_git "remote -v",null,defer err,out
      fetch=out.match(/origin\s*([^\s]*)\s*\(fetch\)/)[1]
      console.log "git url: #{fetch}"

      # detect GithubPage branch
      branch='gh-pages'
      if fetch.match /\.github\.com/
        branch='master'

      # make sure users dont put documents in their GithubPage branch
      await @_git "status",null,defer err,out
      curBranch=out.match(/on\s*branch\s*([^\s]*)/i)[1]
      if curBranch==branch
        console.err "You are in target branch '#{branch}'. Put your documents in another branch!!!"

      # get current gh-pages (make sure git clone done well)
      await mkdirp @tmp,defer err
      await utils.rmdirDeep @tmp,defer err
      console.log "Cloning branch '#{branch}' into '#{@tmp}'"
      await @_git "clone --branch #{branch} #{fetch} #{@tmp}",null,defer err,out

      # make sure GithubPage branch exists
      await @_git "status",@tmp,defer err,out
      if !out.match branch
        console.log "Branch '#{branch}' does not exists. creating..."
        await @_git "branch #{branch}",@tmp,defer err
      await @_git "checkout #{branch}",@tmp,defer err
    else
      await mkdirp @tmp,defer err


    # generate content
    console.log "Generating content..."
    await @_generate layout,defer()

    if !options.out?
      # commit&push back to Github
      await @_git "add --all",@tmp,defer err
      await @_git "commit -m 'compiled by markem'",@tmp,defer err,out
      console.log out
      console.log "Pushing back into origin..."
      await @_git "push origin #{branch}",@tmp,defer err




      await utils.rmdirDeep @tmp,defer err
      console.log "Done."

  # calling git commands
  # params:
  #     command: git sub-commands and options
  #     workTree: git working copy location, default to null
  # callback:
  #     cb(err,stdout,stderr)
  @_git:(command,workTree,cb)->
    if workTree?
      command="git --work-tree #{workTree} --git-dir #{path.join workTree,'.git'} #{command}"
    else
      command="git #{command}"
    await childprocess.exec command,defer err,stdout,stderr
    if @options.verbose
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
  @_generate: (layout,cb)->
    await fs.readdir @tmp,defer err, list
    for file in list
      continue if file.match /^\./
      await fs.stat path.join(@tmp,file),defer err, stat
      if stat.isDirectory()
        console.log "rm -Rf #{file}" if @options.verbose
        await utils.rmdirDeep file,defer err
      else
        console.log "rm -f #{file}" if @options.verbose
        await utils.unlink file,defer err

    console.log "cp -R markem.conf #{@tmp}" if @options.verbose
    await utils.cpdir 'markem.conf',@tmp,defer err

    console.log "rm -f #{path.join(@tmp,'layout.jade')}" if @options.verbose
    await utils.unlink path.join(@tmp,'layout.jade'),defer err
    utils.scandir
      path: @source
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
              target=path.join @tmp,relative.replace /\.markdown$/,'.html'
            if relative.match /\.md$/
              target=path.join @tmp,relative.replace /\.md$/,'.html'
            if relative.match new RegExp("readme\\.md$",'i')
              target=path.join @tmp,relative.replace new RegExp("[^#{path.sep}]*$"),'index.html'
            if target?
              document=
                dirs:[]
                files:[]
                pathSource:'/'+relative
                pathFile:'/'+path.relative(@tmp,target)
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
          
          console.log "rendering #{document.target}" if markem.options.verbose
          await mkdirp path.dirname(document.target),defer err
          try
            document.output=layout document
          catch e
            console.error e
            utils.rmdirDeep @tmp,->
            process.exit 1
            return
          await fs.writeFile document.target,document.output,'utf8',defer err
        cb()