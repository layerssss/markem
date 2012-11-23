utils=require 'bal-util'
mkdirp=require 'mkdirp'
path=require 'path'
jade=require 'jade'
fs=require 'fs'
marked=require 'marked'
childprocess=require 'child_process'

module.exports=markem=
  version:  '0.0.1'
  options: null
  run: (options,cb)->
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
      utils.rmdirDeep 'markem.out',->
      process.exit 1
      return


    # detect Git remote
    this.options=options
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

    # get current gh-pages
    await utils.rmdirDeep 'markem.out',defer err
    console.log "Cloning branch '#{branch}' into 'markem.out'"
    await this._git "clone --branch #{branch} #{fetch} markem.out",null,defer err,out

    # make sure GithubPage branch exists
    await this._git "status",'markem.out',defer err,out
    if !out.match branch
      console.log "Branch '#{branch}' does not exists. creating..."
      await this._git "branch #{branch}",'markem.out',defer err
    await this._git "checkout #{branch}",'markem.out',defer err


    # generate content
    console.log "Generating content..."
    await this._generate layout,defer()


    # commit&push back to Github
    await this._git "add --all",'markem.out',defer err
    await this._git "commit -m 'compiled by markem'",'markem.out',defer err,out
    console.log out
    console.log "Pushing back into origin..."
    await this._git "push origin #{branch}",'markem.out',defer err




    await utils.rmdirDeep 'markem.out',defer err
    console.log "Done."
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
    utils.scandir
      path: 'markem.out',
      readFiles:false
      ignoreHiddenFiles: true
      recurse:false
      next:(err,list)->
        for file,type of list
          file=path.join 'markem.out',file
          if type=='dir'
            await utils.rmdirDeep file,defer err
          else
            await utils.unlink file,defer err
        utils.scandir
          path: '.'
          readFiles: false
          ignoreHiddenFiles: true
          next: (err,list) ->
            for file,type of list
              if type=='file'&&!file.match /node_modules/
                target=null
                if file.match /\.markdown$/
                  target=path.join 'markem.out',file.replace /\.markdown$/,'.html'
                if file.match /\.md$/
                  target=path.join 'markem.out',file.replace /\.md$/,'.html'
                if file in ['READMD','README.md','README.markdown','Readme.md']
                  target=path.join 'markem.out',file.replace new RegExp("[^#{path.sep}]*$"),'index.html'
                if target?
                  await fs.stat file,defer err,fileStat
                  await fs.stat target,defer err,targetStat
                  if err? || Number(fileStat.mtime)-Number(targetStat.mtime)<300
                    if markem.options.verbose
                      console.log "rendering #{target}"
                    await mkdirp path.dirname(target),defer err
                    await fs.readFile file,'utf8',defer err,file
                    try
                      file=marked file
                      file=layout
                        title: (file.match(/<h1>([^<]*)<\/h1>/m)||[null])[1] 
                        content: file
                    catch e
                      console.err e
                      utils.rmdirDeep 'markem.out',->
                      process.exit 1
                      return
                    await fs.writeFile target,file,'utf8',defer err
            cb()