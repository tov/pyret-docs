MANUAL_FONTS = "$(shell racket -e '(display (collection-file-path "manual-fonts.css" "scribble"))')"

all: docs

docs:
	racket run.rkt \
    ++style $(MANUAL_FONTS) \
    ++style ./node_modules/codemirror/lib/codemirror.css \
    ++extra ./node_modules/codemirror/lib/codemirror.js \
    ++extra ./node_modules/codemirror/addon/runmode/runmode.js \
    \
    ++extra ./node_modules/pyret-codemirror-mode/mode/pyret.js \
    ++style ./node_modules/pyret-codemirror-mode/css/pyret.css \
    ++extra src/hilite.js \
    ++extra src/Pyret-Tutorial/airplane-small.png \
    ++extra src/search.js \
    \
    ++style src/styles.css \
    --prefix src/myprefix.html \
    \
    --dest build/ \
    --dest-name docs \
    ++arg "$(VERSION)" \
    --htmls-search src/index.scrbl
	mkdir -p build/docs/search
	cp src/search.html build/docs/search/index.html
	patch build/docs/scribble-common.js src/scribble-common.patch

release-docs: docs
	scp -r build/docs/* $(DOCS_TARGET)/$(VERSION)/
	chmod -R a+rx $(DOCS_TARGET)/$(VERSION)/
	cd $(DOCS_TARGET) && unlink latest && ln -s $(VERSION) latest

install:
	npm install
