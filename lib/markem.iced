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
    this.options=options
    await this._git "remote -v",'.',defer err,out
    fetch=out.match(/origin\s*([^\s]*)\s*\(fetch\)/)[1]
    console.log "git url: #{fetch}"
    await utils.rmdirDeep 'markem.out',defer err
    console.log "cloning into markem.out"
    branch='gh-pages'
    await this._git "clone #{fetch} markem.out",null,defer err,out
    await this._git "branch",'markem.out',defer err,out
    if !out.match branch
      console.log "branch #{branch} does not exists, creating..."
      await this._git "branch #{branch}",'markem.out',defer err
    await this._git "checkout #{branch}",'markem.out',defer err
    console.log "generating content..."
    await this._generate defer()
    await this._git "add --all",'markem.out',defer err
    await this._git "commit -m 'compiled by markem'",'markem.out',defer err
    console.log "pushing back into origin..."
    await this._git "push origin #{branch}",'markem.out',defer err
    await utils.rmdirDeep 'markem.out',defer err
    console.log "done."
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
      if err?
        console.error err
    cb(err,stdout,stderr)
  _generate: (cb)->
    await fs.readFile path.join('markem.conf','layout.jade'),'utf8',defer err,layout
    layout=jade.compile layout,
      filename:path.join('markem.conf','layout.jade')
    utils.scandir
      path: 'markem.out',
      readFiles:false
      ignoreHiddenFiles: true
      recurse:false
      next:(err,list)->
        for file,type of list
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
                  target=path.join 'markem.out',file.replace /[^#{path.sep}]*$/,'index.html'
                if target?
                  await fs.stat file,defer err,fileStat
                  await fs.stat target,defer err,targetStat
                  if err? || Number(fileStat.mtime)-Number(targetStat.mtime)<300
                    console.log "rendering #{target}"
                    await mkdirp path.dirname(target),defer err
                    await fs.readFile file,'utf8',defer err,file
                    file=layout 
                      content: marked file
                    await fs.writeFile target,file,'utf8',defer err
            cb()