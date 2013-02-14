Markem
==================================================
Zero-Configuration Static Site Generator

By Michael Yin

Markem is a zero-configuration, markdown based, simple, Github-friendly, static site generator and publisher. There's only one template needed to generate hell a lot of self-hyperlinked documents and push them to your GithubPage. Or if you feel lazy to setup layout, we got a few skeletons for you. 

How to generate a personal page in 10 seconds?
---------------------------------------------------
Let's assume you have all your documents prepared as markdown format in one of your Github repo. (and you didn't forget README.md)

And, make sure you have nodejs installed.

Then install markem through npm:

    sudo npm install markem -g

Then head to your local Github repo, type

    $ markem

Whaooo~, if everything goes fine, you shall see these:

    1. twitter-boostrap
    Which one do you want to use: 1
    'markem.conf' created.
    git url: git@github.com:layerssss/markem.git
    Cloning branch 'gh-pages' into 'markem.out'
    Branch 'gh-pages' does not exists. creating...
    Generating content...
    [gh-pages 4c03711] compiled by markem
     30 files changed, 75 insertions(+), 20037 deletions(-)
     ...some git log

    Pushing back into origin...
    Done.

There you go, wait for a few minutes(if its the first time you markem), then you can see your page on http://**USERNAME**.gitub.com/**REPONAME**/.

How it works?
---------------------------------------------------

Thanks to Github for providing us such a excellant service. Read more about it on [Github Help](https://help.github.com/articles/what-are-github-pages)

How does it compare to other site generators?
---------------------------------------------------

Markem don't mess up with your repo stucture. All the configuraion is in markem.conf. You can place your docs all arroud in your repo. Yeah, anywhere. Then readers can both read your docs on your page or fork&edit then on github.com.

Ok, markem is just a tool simply can turns markdowns into html, and push them back to github. It's not designated to make a real website/press. It's a tool for really really busy UNIX hackers who's busy hacking on something else, and have no time to write layouts and configuration for a little bunch of docs/slides. So we can in NO WAY call it a CMS, comparing to other tools.

If you need more functionalities, here are some other great tools for you:

* [jekyll](http://jekyllrb.com/) site generator from Github, in Ruby
* [docpad](https://github.com/bevry/docpad) flexible site generator make in nodejs, with lots of plugins&skeletons

What if I want to make a USERNAME.github.com page?
---------------------------------------------------

Good, markem works fine in this case. You just need to put your docs in a git branch other than 'master' (e.g. 'docs'). And markem will change your target branch from 'gh-pages' to 'master'.

Features
---------------------------------------------------

* use only one layout.jade as your template 
* static files support
* automatic publishing
* pre-made skeletons!

Installation
---------------------------------------------------
    
    sudo npm install markem -g


Usage
---------------------------------------------------
     
      Usage: markem [options]

      Options:

        -h, --help          output usage information
        -V, --version       output the version number
        -o, --out <dir>     output the generated site to <dir> instead of pushing to GtihubPage
        -v, --verbose       output additional logs
        -s, --source <dir>  use specific doc source instead of cwd

License
---------------------------------------------------

(The MIT License)

Copyright (c) 2012-2012 Michael Yin <layerssss@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.