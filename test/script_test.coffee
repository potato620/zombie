{ assert, brains, Browser } = require("./helpers")


describe "Scripts", ->

  before (done)->
    brains.ready done


  describe "basic", ->
    before ->
      brains.get "/script/living/", (req, res)->
        res.send """
        <html>
          <head>
            <script src="/jquery.js"></script>
            <script src="/sammy.js"></script>
            <script src="./app.js"></script>
          </head>
          <body>
            <div id="main">
              <a href="/script/dead">Kill</a>
              <form action="#/dead" method="post">
                <label>Email <input type="text" name="email"></label>
                <label>Password <input type="password" name="password"></label>
                <button>Sign Me Up</button>
              </form>
            </div>
            <div class="now">Walking Aimlessly</div>
          </body>
        </html>
        """

      brains.get "/script/living/app.js", (req, res)->
        res.send """
        Sammy("#main", function(app) {
          app.get("#/", function(context) {
            document.title = "The Living";
          });
          app.get("#/dead", function(context) {
            context.swap("The Living Dead");
          });
          app.post("#/dead", function(context) {
            document.title = "Signed up";
          });
        });
        $(function() { Sammy("#main").run("#/") });
        """

    describe "run app", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/script/living/", done

      it "should execute route", ->
        assert.equal browser.document.title, "The Living"
      it "should change location", ->
        assert.equal browser.location.href, "http://localhost:3003/script/living/#/"

      describe "move around", ->
        before (done)->
          browser.visit browser.location.href + "dead", done

        it "should execute route", ->
          assert.equal browser.text("#main"), "The Living Dead"
        it "should change location", ->
          assert.equal browser.location.href, "http://localhost:3003/script/living/#/dead"


    describe "live events", ->
      browser = new Browser()

      before (done)->
        browser.visit "http://localhost:3003/script/living/", ->
          browser.fill "Email", "armbiter@zombies"
          browser.fill "Password", "br41nz"
          browser.pressButton "Sign Me Up"
          browser.wait 500, done

      it "should change location", ->
        assert.equal browser.location.href, "http://localhost:3003/script/living/#/"
      it "should process event", ->
        assert.equal browser.document.title, "Signed up"


    describe "evaluate", ->
      title = null

      before (done)->
        Browser.visit "http://localhost:3003/script/living/", (_, browser)->
          title = browser.evaluate "document.title"
          done()

      it "should evaluate in context and return value", ->
        assert.equal title, "The Living"


  describe "evaluating", ->

    describe "context", ->
      browser = new Browser()

      before (done)->
        brains.get "/script/context", (req, res)->
          res.send """
          <html>
            <script>var foo = 1</script>
            <script>window.foo = foo + 1</script>
            <script>document.title = this.foo</script>
            <script>
            setTimeout(function() {
              document.title = foo + window.foo
            });</script>
          </html>
          """
        browser.visit "http://localhost:3003/script/context", done

      it "should be shared by all scripts", ->
        assert.equal browser.text("title"), "4"


    describe "window", ->
      browser = new Browser()

      before (done)->
        brains.get "/script/window", (req, res)->
          res.send """
          <html>
            <script>document.title = [window == this,
                                      this == window.window,
                                      this == top,
                                      top == window.top,
                                      this == parent,
                                      top == parent].join(',')</script>
          </html>
          """
        browser.visit "http://localhost:3003/script/window", done

      it "should be the same as this, top and parent", ->
        assert.equal browser.text("title"), "true,true,true,true,true,true"


    describe "global and function", ->
      browser = new Browser()

      before (done)->
        brains.get "/script/global_and_fn", (req, res)->
          res.send """
          <html>
            <script>
              var foo;
              (function() {
                if (!foo)
                  foo = "foo";
              })()
              document.title = foo;
            </script>
          </html>
          """
        browser.visit "http://localhost:3003/script/global_and_fn", done

      it "should not fail with an error", ->
        assert.equal browser.errors.length, 0
      it "should set global variable", ->
        assert.equal browser.text("title"), "foo"


  describe "order", ->
    browser = new Browser()

    before (done)->
      brains.get "/script/order", (req, res)->
        res.send """
        <html>
          <head>
            <title>Zero</title>
            <script src="/script/order.js"></script>
          </head>
          <body>
            <script>
              document.title = document.title + "Two";
            </script>
          </body>
        </html>
        """
      brains.get "/script/order.js", (req, res)->
        res.send "document.title = document.title + 'One'"
      browser.visit "http://localhost:3003/script/order", done

    it "should run scripts in order regardless of source", ->
      assert.equal browser.text("title"), "ZeroOneTwo"


  describe "eval", ->
    browser = new Browser()

    before (done)->
      brains.get "/script/eval", (req, res)->
        res.send """
        <html>
          <script>
            var foo = "One";
            (function() {
              var bar = "Two"; // standard eval sees this
              var e = eval; // this 'eval' only sees global scope
              try {
                var baz = e("bar");
              } catch (ex) {
                var baz = "Three";
              }
              // In spite of local variable, global scope eval finds global foo
              var foo = "NotOne";
              var e_foo = e("foo");
              var qux = window.eval.call(window, "foo");

              document.title = eval('e_foo + bar + baz + qux');
            })();
          </script>
        </html>
        """
      browser.visit "http://localhost:3003/script/eval", done

    it "should evaluate in global scope", ->
      assert.equal browser.document.title, "OneTwoThreeOne"


  describe "failing", ->
    describe "incomplete", ->
      browser = new Browser()
      error = null

      before (done)->
        brains.get "/script/incomplete", (req, res)->
          res.send """
            <html>
              <script>1+</script>
            </html>
          """
        browser.visit "http://localhost:3003/script/incomplete", (_)->
          error = _
          done()

      it "should pass error to callback", ->
        assert.equal error.message, "Unexpected end of input"

      it "should propagate error to window", ->
        assert.equal browser.error.message, "Unexpected end of input"

    describe "error", ->
      browser = new Browser()
      error = null

      before (done)->
        brains.get "/script/error", (req, res)->
          res.send """
            <html>
              <script>(function(foo) { foo.bar })()</script>
            </html>
          """
        browser.visit "http://localhost:3003/script/error", (_)->
          error = _
          done()

      it "should pass error to callback", ->
        assert.equal error.message, "Cannot read property 'bar' of undefined"

      it "should propagate error to window", ->
        assert.equal browser.error.message, "Cannot read property 'bar' of undefined"


  describe "loading", ->

    describe "with entities", ->
      browser = new Browser()

      before (done)->
        brains.get "/script/split", (req, res)->
          res.send """
          <html>
            <script>foo = 1 < 2 ? 1 : 2; '&'; document.title = foo</script>
          </html>
          """
        browser.visit "http://localhost:3003/script/split", done

      it "should run full script", ->
        assert.equal browser.text("title"), "1"

    # NOTE: htmlparser can't deal with CDATA sections
    ###
    describe "with CDATA", ->
      browser = new Browser()

      before (done)->
        brains.get "/script/cdata", (req, res)-> res.send """
          <html>
            <script>foo = 2; <![CDATA[ document.title ]]> = foo</script>
          </html>
          """
        browser.visit "http://localhost:3003/script/cdata", done

      it "should run full script", ->
        assert.equal browser.text("title"), "2"
    ###

    # NOTE: htmlparser can't deal with document.write.
    describe "using document.write", ->
      browser = new Browser()

      before (done)->
        brains.get "/script/write", (req, res)-> res.send """
          <html>
            <body>
            <script>document.write(unescape(\'%3Cscript %3Edocument.title = document.title + ".write"%3C/script%3E\'));</script>
            <script>
              document.title = document.title + "document";
            </script>
            </body>
          </html>
          """
        browser.visit "http://localhost:3003/script/write", done

      it "should run script", ->
        assert.equal browser.document.title, "document.write"


    describe "using appendChild", ->
      browser = new Browser()

      before (done)->
        brains.get "/script/append", (req, res)->
          res.send """
          <html>
            <head>
              <script>
                var s = document.createElement('script'); s.type = 'text/javascript'; s.async = true;
                s.src = '/script/append.js';
                (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(s);
              </script>
            </head>
            <body>
              <script>
                document.title = document.title + "element.";
              </script>
            </body>
          </html>
          """
        brains.get "/script/append.js", (req, res)->
          res.send "document.title = document.title + \"appendChild\""
        browser.visit "http://localhost:3003/script/append", done

      it "should run script", ->
        assert.equal browser.document.title, "element.appendChild"


  describe "scripts disabled", ->
    browser = new Browser(runScripts: false)

    before (done)->
      brains.get "/script/no-scripts", (req, res)->
        res.send """
        <html>
          <head>
            <title>Zero</title>
            <script src="/script/no-scripts.js"></script>
          </head>
          <body>
            <script>
            document.title = document.title + "Two";</script>
          </body>
        </html>
        """
      brains.get "/script/no-scripts.js", (req, res)->
        res.send "document.title = document.title + 'One'"
      browser.visit "http://localhost:3003/script/order", done

    it "should not run scripts", ->
      assert.equal browser.document.title, "Zero"


  describe "file:// uri scheme", ->
    browser = new Browser()

    before (done)->
      browser.visit "file://#{__dirname}/data/file_scheme.html", ->
        setTimeout done, 100

    it "should run scripts with file url src", ->
      assert.equal browser.document.title, "file://"


  describe "javascript: URL", ->
    browser = new Browser()

    before (done)->
      browser.visit "javascript:document.write('hi')", ->
        done()

    it "should evaluate script in context of window", ->
      assert.equal browser.text(), "hi"


  describe "new Image", ->
    browser = new Browser()

    before (done)->
      browser.visit "http://localhost:3003/script/living/", done

    it "should construct an img tag", ->
      assert.equal browser.evaluate("new Image").tagName, "IMG"
    it "should construct an img tag with width and height", ->
      assert.equal browser.evaluate("new Image(1, 1)").height, 1


  describe "Event", ->
    browser = new Browser()

    it "should be available in global context", ->
      assert browser.evaluate("Event")


  describe "on- event handler", ->
    browser = new Browser()

    before (done)->
      brains.get "/script/event", (req, res)->
        res.send """
          <form onsubmit="document.title = event.eventType; return false">
            <button>Submit</button>
          </form>
        """
      brains.ready done

    before (done)->
      browser.visit "http://localhost:3003/script/event", ->
        browser.pressButton "Submit", done

    it "should prevent default handling by returning false", ->
      assert.equal browser.location.href, "http://localhost:3003/script/event"

    it "should have access to window.event", ->
      assert.equal browser.document.title, "HTMLEvents"

