::  How the host answers requests and builds: HEAD of the files it put in
::  Eyre's cache, owner responses no cache may store, routes only pages
::  share, bounded import names, -jibb!test's argument and results, and
::  the scry thread's answers.
/+  jibb-host
|%
++  routes
  ^-  (list route:jibb-host)
  ~[[%my-app /apps/my-app]]
++  cache-with
  |=  page=cached-page:jibb-host
  ^-  page-cache:jibb-host
  =/  pages=(map (list @t) cached-page:jibb-host)
    (~(gas by *(map (list @t) cached-page:jibb-host)) ~[[~ page]])
  (~(gas by *(map desk desk-pages:jibb-host)) ~[[%my-app [pages ~]]])
++  cache
  ^-  page-cache:jibb-host
  (cache-with (successful-page:jibb-host '<h1>About this ship</h1>'))
++  status
  |=  result=payload:jibb-host
  ^-  @ud
  status-code.response-header.result
++  cache-control
  |=  result=payload:jibb-host
  ^-  (unit @t)
  (get-header:http 'cache-control' headers.response-header.result)
::  Eyre answers a GET for a file in its cache, but passes a HEAD on to
::  the host, which once answered 404.  It now gets the GET's status and
::  headers, logged in or not, and no body.
++  test-head-of-published-files
  ^-  tang
  =/  file=@t  (static-url:jibb-host /apps/my-app /static/img/[~.logo.png] [3 'abc'])
  =/  font=@t  (static-url:jibb-host /apps/my-app /static/fonts/[~.inter.woff2] [3 'abc'])
  =/  sheet=@t  (stylesheet-url:jibb-host /apps/my-app 'p{}')
  =/  module=@t  (module-url:jibb-host /apps/my-app 'export {}')
  =/  library=@t  (library-url:jibb-host /apps/my-app 'export {}')
  =/  retired=@t  (static-url:jibb-host /apps/my-app /static/img/[~.old.png] [3 'abd'])
  =/  published=(map desk cached-urls:jibb-host)
    %-  malt
    ^-  (list [desk cached-urls:jibb-host])
    :~  :-  %my-app
        %-  malt
        ^-  (list [@t (unit @da)])
        ~[[file ~] [font ~] [sheet ~] [module ~] [library ~] [retired `~2026.11.17]]
    ==
  =/  files=(list [url=@t type=@t])
    :~  [file 'image/png']
        [font 'font/woff2']
        [sheet 'text/css; charset=utf-8']
        [module 'text/javascript; charset=utf-8']
        [library 'text/javascript; charset=utf-8']
        [retired 'image/png']
    ==
  =/  wrong=(list @t)
    %+  murn  files
    |=  [url=@t type=@t]
    =/  get=payload:jibb-host  (static-payload:jibb-host type [3 'abc'])
    =/  head=payload:jibb-host
      (serve:jibb-host routes cache published ~ | %'HEAD' url)
    ?:  ?&  =(200 (status head))
            =(response-header.get response-header.head)
            =(~ data.head)
        ==
      ~
    `url
  ?^  wrong  ~[leaf+"a HEAD of {(trip i.wrong)} did not get its GET's headers"]
  ::  The types the host publishes its stylesheet and scripts with are the
  ::  ones their URLs name.
  ?.  =(`css-type:jibb-host (url-type:jibb-host sheet))  ~[leaf+"the stylesheet's URL named another type"]
  ?.  =(`js-type:jibb-host (url-type:jibb-host module))  ~[leaf+"a module's URL named another type"]
  ::  A GET that reaches the host for a file is still a 404; so is a HEAD
  ::  of a file Eyre does not hold, or of a published URL with a query,
  ::  which is another entry in Eyre's cache.
  ?.  =(404 (status (serve:jibb-host routes cache published ~ | %'GET' file)))
    ~[leaf+"a GET for a published file was answered by the host"]
  ?.  =(404 (status (serve:jibb-host routes cache published ~ & %'HEAD' '/apps/my-app/static/0v1/img/logo.png')))
    ~[leaf+"a HEAD of a file no build made was answered"]
  ?.  =(404 (status (serve:jibb-host routes cache published ~ | %'HEAD' (cat 3 file '?v=1'))))
    ~[leaf+"a HEAD of a published URL with a query was answered as the file"]
  ~
::  Every response to the owner says no cache may store it: private pages
::  are never cached (Decisions: Private pages).  The login redirect and the
::  public files are not marked.
++  test-owner-responses-are-not-stored
  ^-  tang
  =/  error=page-cache:jibb-host
    (~(gas by *(map desk desk-pages:jibb-host)) ~[[%my-app [~ `'the desk could not build']]])
  =/  answers=(list [what=tape result=payload:jibb-host])
    :~  ["a page" (serve:jibb-host routes cache ~ ~ & %'GET' '/apps/my-app')]
        ["a page's HEAD" (serve:jibb-host routes cache ~ ~ & %'HEAD' '/apps/my-app')]
        :-  "a failed page"
        (serve:jibb-host routes (cache-with (failed-page:jibb-host 'boom')) ~ ~ & %'GET' '/apps/my-app')
        ["a missing page" (serve:jibb-host routes cache ~ ~ & %'GET' '/apps/my-app/missing')]
        ["an unrouted path" (serve:jibb-host routes cache ~ ~ & %'GET' '/apps/other')]
        ["a refused method" (serve:jibb-host routes cache ~ ~ & %'POST' '/apps/my-app')]
        ["a build in progress" (serve:jibb-host routes ~ ~ (sy ~[%my-app]) & %'GET' '/apps/my-app')]
        ["a desk's error" (serve:jibb-host routes error ~ ~ & %'GET' '/apps/my-app')]
    ==
  =/  stored=(list tape)
    %+  murn  answers
    |=  [what=tape result=payload:jibb-host]
    ?:  =(`'no-store' (cache-control result))  ~
    `what
  ?^  stored  ~[leaf+"{i.stored} to the owner could be stored by a cache"]
  =/  page=payload:jibb-host  (serve:jibb-host routes cache ~ ~ & %'HEAD' '/apps/my-app')
  ?.  &(=(200 (status page)) =(~ data.page))  ~[leaf+"a page's HEAD changed"]
  ?.  =(~ (cache-control (serve:jibb-host routes cache ~ ~ | %'GET' '/apps/my-app')))
    ~[leaf+"the login redirect was marked"]
  ?.  =(~ (cache-control (serve:jibb-host routes cache ~ ~ | %'GET' '/apps/my-app/static/0v1/a.png')))
    ~[leaf+"the public 404 for a file was marked"]
  =/  twice=payload:jibb-host
    (private:jibb-host (private:jibb-host (html-response:jibb-host '<p>x</p>')))
  =/  marks=(list [key=@t value=@t])
    (skim headers.response-header.twice |=([key=@t value=@t] =(key 'cache-control')))
  ?.  =(~[['cache-control' 'no-store']] marks)  ~[leaf+"marking a response twice repeated the header"]
  ~
::  Only modules a build serves at their sites can conflict: pages, and
::  modules that failed but may be pages.  An island at /ui/todo.jibb or a
::  library at /ui/blog/_util.jibb once failed the pages beside them.
++  test-only-routed-modules-conflict
  ^-  tang
  =/  modules=(list [at=path site=(list @t) kind=(each @tas ?)])
    :~  [/ui/todo/jibb ~['todo'] [%& %island]]
        [/ui/todo/index/jibb ~['todo'] [%& %static-page]]
        [/ui/blog/[~._util]/jibb ~['blog' '_util'] [%& %library]]
        [/ui/blog/[~._slug]/jibb ~['blog' '_slug'] [%& %page]]
        [/ui/cart/jibb ~['cart'] [%& %store]]
        [/ui/cart/index/jibb ~['cart'] [%& %page]]
        [/ui/tests/sums/jibb ~['tests' 'sums'] [%& %library]]
        [/ui/broken/jibb ~['broken'] [%| &]]
        [/ui/broken-library/jibb ~['broken-library'] [%| |]]
    ==
  =/  routed=(list [at=path site=(list @t)])  (routed-sites:jibb-host modules)
  =/  expected=(list [at=path site=(list @t)])
    :~  [/ui/todo/index/jibb ~['todo']]
        [/ui/blog/[~._slug]/jibb ~['blog' '_slug']]
        [/ui/cart/index/jibb ~['cart']]
        [/ui/broken/jibb ~['broken']]
    ==
  ?.  =(expected routed)  ~[leaf+"the routed modules were not the pages and failed possible pages"]
  ?.  =(~ (route-conflicts:jibb-host routed))
    ~[leaf+"an island, store or library made a page's route conflict"]
  ::  Over every module, as before, the pages had conflicted.
  =/  all=(map path @t)
    (route-conflicts:jibb-host (turn modules |=(m=[at=path site=(list @t) *] [at.m site.m])))
  ?.  (~(has by all) /ui/todo/index/jibb)  ~[leaf+"the control did not conflict over every module"]
  ::  Two pages, or a page and a failed module that may be one, conflict.
  =/  clash=(map path @t)
    %-  route-conflicts:jibb-host
    %-  routed-sites:jibb-host
    :~  [/ui/a/jibb ~['a'] [%| &]]
        [/ui/a/index/jibb ~['a'] [%& %page]]
        [/ui/b/[~._x]/jibb ~['b' '_x'] [%& %page]]
        [/ui/b/[~._y]/jibb ~['b' '_y'] [%& %static-page]]
    ==
  =/  same=@t
    'route conflict: /ui/a/index.jibb and /ui/a.jibb both route to the same address'
  ?.  =(`same (~(get by clash) /ui/a/index/jibb))  ~[leaf+"a page and a failed possible page did not conflict"]
  ?.  (~(has by clash) /ui/b/[~._y]/jibb)  ~[leaf+"two pages' parameters at one level did not conflict"]
  ~
::  Each dash doubles Clay's candidate paths for a /- or /% name.  Like the
::  importer's Ford imports, a name may have at most ten dashes; past that
::  it is not searched, and its importer reports the budget.
++  test-import-names-are-bounded
  ^-  tang
  =/  ten=(unit (list path))  (name-paths:jibb-host %a-b-c-d-e-f-g-h-i-j-k)
  ?~  ten  ~[leaf+"a name with ten dashes was not searched"]
  ?.  =(1.024 (lent u.ten))  ~[leaf+"a name with ten dashes did not have 1,024 candidates"]
  ?.  =(~ (name-paths:jibb-host %a-b-c-d-e-f-g-h-i-j-k-l))
    ~[leaf+"a name with eleven dashes was searched"]
  =/  modules=(map path module-info:jibb-host)
    %-  malt
    ^-  (list [path module-info:jibb-host])
    :~  [/ui/long/jibb [/ui/long/jibb 'source' 0v1 ~ ~[%a-b-c-d-e-f-g-h-i-j-k-l] ~ | ~]]
        [/ui/short/jibb [/ui/short/jibb 'source' 0v2 ~ ~[%todo] ~[%todo-action] | ~]]
        [/ui/marks/jibb [/ui/marks/jibb 'source' 0v3 ~ ~ ~[%a-b-c-d-e-f-g-h-i-j-k-l] | ~]]
    ==
  =/  surs=(map term path)  (malt `(list [term path])`~[[%todo /sur/todo/hoon]])
  =/  marks=(map term path)  (malt `(list [term path])`~[[%todo-action /mar/todo/action/hoon]])
  =/  long=@t
    'static build: /ui/long.jibb imports /- a-b-c-d-e-f-g-h-i-j-k-l, but a /- or /% name may have at most ten dashes'
  ?.  =(`long (missing-import:jibb-host modules surs marks ~[/ui/long/jibb]))
    ~[leaf+"a /- name past the budget did not fail its importer"]
  =/  long-mark=@t
    'static build: /ui/marks.jibb imports /% %a-b-c-d-e-f-g-h-i-j-k-l, but a /- or /% name may have at most ten dashes'
  ?.  =(`long-mark (missing-import:jibb-host modules surs marks ~[/ui/marks/jibb]))
    ~[leaf+"a /% name past the budget did not fail its importer"]
  =/  sur=@t  'static build: /ui/short.jibb imports /- todo, which has no /sur file'
  ?.  =(`sur (missing-import:jibb-host modules ~ marks ~[/ui/short/jibb]))
    ~[leaf+"a /- name with no file lost its error"]
  =/  mark=@t  'static build: /ui/short.jibb imports /% %todo-action, which has no /mar file'
  ?.  =(`mark (missing-import:jibb-host modules surs ~ ~[/ui/short/jibb]))
    ~[leaf+"a /% name with no file lost its error"]
  ?.  =(~ (missing-import:jibb-host modules surs marks ~[/ui/short/jibb]))
    ~[leaf+"found imports were reported missing"]
  ~
::  Dojo runs -jibb!test %desk with [~ %desk]; older callers passed
::  [%desk ~].  Anything else is a usage error, not a crash: a cord's type
::  fits a desk's, so a name that is not a term is refused too.
++  test-jibb-test-takes-the-dojo-argument
  ^-  tang
  ?.  =(`%my-app (test-desk:jibb-host !>([~ %my-app])))  ~[leaf+"dojo's argument was refused"]
  ?.  =(`%my-app (test-desk:jibb-host !>([%my-app ~])))  ~[leaf+"the older argument was refused"]
  ?.  =(~ (test-desk:jibb-host !>(~)))  ~[leaf+"no argument named a desk"]
  ?.  =(~ (test-desk:jibb-host !>([~ 'My App'])))  ~[leaf+"a name that is not a term was taken for a desk"]
  ?.  =(~ (test-desk:jibb-host !>([~ %my-app %other])))  ~[leaf+"two arguments named a desk"]
  ~
::  -jibb!test runs the tests of the desk's last completed build; one that
::  could not run is their failure, not an older build's results.
++  test-failed-builds-fail-their-tests
  ^-  tang
  =/  good=build:jibb-host  (new-build:jibb-host 7 /apps/my-app)
  ?.  =([%& good] (completed-tests:jibb-host %my-app `good))  ~[leaf+"a completed build's tests did not run"]
  =/  broken=build:jibb-host  good(rev 8, failure `'static build: /lib/jibb-build.hoon does not build')
  =/  expected=@t
    '%my-app revision 8 did not build: static build: /lib/jibb-build.hoon does not build'
  ?.  =([%| expected] (completed-tests:jibb-host %my-app `broken))
    ~[leaf+"a build that could not run did not fail its tests"]
  ?.  =([%| '%my-app has no completed build'] (completed-tests:jibb-host %my-app ~))
    ~[leaf+"a desk with no build had tests"]
  ~
::  The scry thread gives the agent's noun, or ~ when the agent did not
::  answer, the page's 404.  A failed thread did not read: its failure, a
::  500, where the host once called every failure the agent's.
++  test-scry-thread-answers
  ^-  tang
  ?.  =([%& `[%post 'Hi']] (scry-answer:jibb-host [%& %noun !>(`*`[~ %post 'Hi'])]))
    ~[leaf+"the agent's answer was lost"]
  ?.  =([%& ~] (scry-answer:jibb-host [%& %noun !>(~)]))
    ~[leaf+"a path the agent did not answer was not the page's 404"]
  ?.  =([%& `~] (scry-answer:jibb-host [%& %noun !>(`*`[~ ~])]))
    ~[leaf+"an answer of ~ was taken for no answer"]
  =/  crashed=(each (unit *) tang)
    (scry-answer:jibb-host [%| %thread-fail ~[leaf+"crashed"]])
  ?.  =([%| ~[leaf+"%thread-fail" leaf+"crashed"]] crashed)
    ~[leaf+"a failed thread was taken for the agent's answer"]
  =/  malformed=(each (unit *) tang)  (scry-answer:jibb-host [%& %noun !>(5)])
  ?.  ?=(%| -.malformed)  ~[leaf+"a malformed answer was taken for the agent's"]
  ~
--
