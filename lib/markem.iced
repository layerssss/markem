
mkdirp = require 'mkdirp'
path = require 'path'
jade = require 'jade'
fs = require 'fs'
marked = require 'marked'
childprocess = require 'child_process'
html_encoder = require 'node-html-encoder'


entityEncoder = new html_encoder.Encoder 'entity'

module.exports = class markem
  @version:  require('../package.json').version
  @options: null
  @run: (options,cb)->
    @options = options
    @tmp = options.out||'markem.out'
    @source = path.resolve options.source||'.'
    @json = JSON.parse options.json||'{}'

    # serving skeletons
    await fs.exists path.join(@source, 'markem.conf'), defer exists
    if !exists
      await fs.readdir path.join(__dirname, '..', 'skeletons'), defer e, layouts
      layouts = layouts.filter (layout)-> !layout.match /^\./
      console.log "Seems like you havn't got a layout for your site. You can choose one skeleton from below."
      for layout, i in layouts
        console.log "#{i+1}. #{layout}"
      process.stdout.write "Which one do you want to use: "
      process.stdin.setEncoding 'utf8'
      process.stdin.resume()
      await process.stdin.on 'data', defer input
      layout = null
      try
        layout = layouts[Number(input)-1]
      catch e
        return cb e
      process.stdin.pause()
      if !layout?
        return cb new Error 'not a valid input'
      await mkdirp 'markem.conf', defer e
      return cb e if e
      await @depthFirstTraverse path.join(__dirname, '..', 'skeletons', layout), defer e, files, directories
      return cb e if e
      directories.reverse()
      for item in directories
        item_new = item.substring path.join(__dirname, '..', 'skeletons', layout).length
        item_new = path.join(@source, 'markem.conf') + item_new
        await fs.mkdir item_new, defer e
        return cb e if e
      for item in files
        item_new = item.substring path.join(__dirname, '..', 'skeletons', layout).length
        item_new = path.join(@source, 'markem.conf') + item_new
        await fs.readFile item, defer e, data
        return cb e if e
        await fs.writeFile item_new, data, defer e
        return cb e if e
      return cb e if e
      console.log "'markem.conf' created."

    # prepare template
    await fs.readFile path.join(@source, 'markem.conf', 'layout.jade'), 'utf8', defer e, layout
    return cb e if e
    try
      layout = jade.compile layout, 
        filename:path.join(@source, 'markem.conf', 'layout.jade')
    catch e
      return cb e


    # detect Git remote
    await @_git ['remote', '-v'], @source, defer e, out
    fetch = out.match(/origin\s+([^\s]+)\s+\(fetch\)/)?[1]
    if fetch
      @repo = fetch.match(/([0-9a-z\-\_\.]+\/[0-9a-z\-\_\.]+)\.git/i)?[1]
      console.log "git url: #{fetch}" 
      console.log "repo: #{@repo}" if @repo

    if !options.out?
      return cb new Error 'not a git repo' unless fetch

      # detect GithubPage branch
      branch = 'gh-pages'
      if fetch.match /\.github\.com|\.github\.io/
        branch = 'master'
      # make sure users dont put documents in their GithubPage branch
      await @_git ['status'], @source, defer e, out
      curBranch = out.match(/on\s*branch\s*([^\s]*)/i)[1]
      if curBranch == branch
        return cb new Error "You are in target branch '#{branch}'. Please put your documents in another branch."

      # get current gh-pages (make sure git clone done well)
      await mkdirp @tmp, defer e
      return cb e if e
      await @depthFirstTraverse @tmp, defer e, files, directories
      return cb e if e
      for file in files
        await fs.unlink file, defer e
        return cb e if e
      for file in directories
        await fs.rmdir file, defer e
        return cb e if e
      await fs.rmdir @tmp, defer e

      console.log "Cloning branch '#{branch}' into '#{@tmp}'"
      await @_git ['clone', '--branch', branch, fetch, @tmp], null, defer e, out

      # make sure GithubPage branch exists
      await @_git ["status"], @tmp, defer e, out
      if !out.match branch
        console.log "Branch '#{branch}' does not exists. creating..."
        await @_git ['branch', branch], @tmp, defer e
      await @_git ['checkout', branch], @tmp, defer e
    else
      await mkdirp @tmp, defer e


    # generate content
    console.log "Generating content..."
    await @_generate layout, defer e
    return cb e if e

    if !options.out?
      # commit&push back to Github
      await @_git ['add', '--all'], @tmp, defer e
      await @_git ['commit', '-m', 'compiled by markem'], @tmp, defer e, out
      console.log out||''
      console.log "Pushing back into origin..."
      await @_git ['push', 'origin', branch], @tmp, defer e
      return cb e if e

      await @depthFirstTraverse @tmp, defer e, files, directories
      return cb e if e
      for file in files
        await fs.unlink file, defer e
        return cb e if e
      for file in directories
        await fs.rmdir file, defer e
        return cb e if e
      await fs.rmdir @tmp, defer e
      console.log "Done."

    cb()

  @depthFirstTraverse: (pathname, cb)->
    files = []
    directories = []
    await fs.readdir pathname, defer e, list
    return cb e if e
    for item in list
      pathname_new = (path.join pathname, item)
      await @depthFirstTraverse pathname_new, defer e, files_new, directories_new
      if e
        files.push pathname_new
      else
        files.push file for file in files_new
        directories.push directory for directory in directories_new
        directories.push pathname_new
    cb null, files, directories

  # calling git commands
  # params:
  #     command: git sub-commands and options
  #     workTree: git working copy location,  default to null
  # callback:
  #     cb(err, stdout, stderr)
  @_git: (command, workTree, cb)->
    args = command
    if workTree?
      await @_spawn workTree, 'git', args, defer e, stdout
    else
      await @_spawn null, 'git', args, defer e, stdout

    cb e,  stdout

  @_spawn: (wd, exec,  args,  cb)->
    console.log "#{wd||''}> #{exec} #{args.join ' '}" if @options.verbose
    proc = childprocess.spawn exec,  args, 
      cwd: wd
    proc.stdout.setEncoding 'utf8'
    proc.stderr.setEncoding 'utf8' 
    out = []
    self = @
    proc.stdout.on 'data', (data)->
      process.stdout.write data if self.options.verbose
      out.push data
    proc.stderr.on 'data', (data)->
      process.stderr.write data if self.options.verbose
      out.push data
    await proc.on 'close',  defer code
    if code
      return cb new Error out.join ''
    cb null, out.join ''
  @_generate: (layout, cb)->
    await @depthFirstTraverse @tmp, defer e, files, directories
    return cb e if e
    for file in files
      continue if 0 == file.indexOf path.join @tmp, '.git'
      await fs.unlink file, defer e
      return cb e if e
    for file in directories
      continue if 0 == file.indexOf path.join @tmp, '.git'
      await fs.rmdir file, defer e
      return cb e if e

    await @depthFirstTraverse @source, defer e, files, directories
    return cb e if e
    globals = @json
    globals.repo = @repo
    documents = {}

    # initialize some basic stuff
    for file in files
      relative = file.substring @source.length + 1
      unless (relative.match /(^|\/|\\)\./)||(relative.match /node_modules/)
        target = null
        if relative.match /\.markdown$/
          target = path.join @tmp, relative.replace /\.markdown$/, '.html'
        if relative.match /\.md$/
          target = path.join @tmp, relative.replace /\.md$/, '.html'
        if relative.match new RegExp("readme\\.md$", 'i')
          target = path.join @tmp, relative.replace new RegExp("[^#{path.sep}]*$"), 'index.html'
        if target?
          target = target.replace /(^|\/)[\.\-\_0-9]+/g, (m, m1)-> m1
          document = 
            dirs: []
            files: []
            pathSource: '/'+relative
            pathFile: '/'+path.relative(@tmp, target)
            target: target
            globals: globals
            slug: String target.match /[^\/]*$/
          document.path = document.pathFile.replace(/\/index\.html$/, '/')
          document.rootPath = path.relative document.path.replace(/\/[^\/]*$/, '/'), '\/'
          if !document.rootPath.length
            document.rootPath = '.'
          documents[document.path] = document
          await fs.readFile path.join(@source,  relative), 'utf8', defer e, document.source
          await fs.stat path.join(@source,  relative),  defer e, document.stats
        else
          continue if relative in ['markem.conf/layout.jade']
          await fs.readFile path.join(@source, relative), defer e, data
          return cb e if e
          target = path.join @tmp, relative.replace /^markem\.conf\//, ''
          await mkdirp (path.dirname target), defer e
          cb e if e
          await fs.writeFile target, data, defer e
          return cb e if e


    # build relationships, content, title between documents
    for p, document of documents
      document.content = marked document.source
      document.title = entityEncoder.htmlDecode document.content.match(/<h1\s[^<]*>([^<]*)<\/h1>/m)?[1]||'untitled'
      document.mete = {}
      document.content.replace /<meta\s+name=\"([^\"]+)\"\s+content=\"([^\"]*)\"\s*\/\s*>/gm, (dummy, name, content)->
        document.mete[name] = entityEncoder.htmlDecode content
        ""
      if p == '/'
        globals.root = document
      if p.match /\/$/
        document.parent = documents[p.replace(/[^\/]*\/$/, '')]
        document.type = 'dir'
      else
        document.parent = documents[p.replace(/[^\/]+$/, '')]
        document.type = 'file'
      if document.parent?
        if document.type == 'dir'
          document.parent.dirs.push document
        else
          document.parent.files.push document
      document.document = document
      documentComparer = (a, b)-> 
        return -1 if a.pathSource < b.pathSource
        return 1 if a.pathSource > b.pathSource
        return 0
      document.files.sort documentComparer
      document.dirs.sort documentComparer

    try
      markemConf = require path.join process.cwd(), 'markem.conf'
    catch e
    if markemConf? and markemConf.preRender?
      await markemConf.preRender globals, defer e
      return cb e if e

    # render each documents
    for p, document of documents
      
      console.log "rendering #{document.target}" if markem.options.verbose
      await mkdirp path.dirname(document.target), defer e
      try
        document.output = layout document
      catch e
        return cb e
      await fs.writeFile document.target, document.output, 'utf8', defer e
    cb()
