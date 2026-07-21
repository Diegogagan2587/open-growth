# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/lib", under: "lib"
pin "@codemirror/lang-markdown", to: "@codemirror--lang-markdown.js" # @6.5.1
pin "codemirror" # @6.0.2
pin "@codemirror/autocomplete", to: "@codemirror--autocomplete.js" # @6.20.3
pin "@codemirror/commands", to: "@codemirror--commands.js" # @6.10.4
pin "@codemirror/lang-css", to: "@codemirror--lang-css.js" # @6.3.1
pin "@codemirror/lang-html", to: "@codemirror--lang-html.js" # @6.4.11
pin "@codemirror/lang-javascript", to: "@codemirror--lang-javascript.js" # @6.2.5
pin "@codemirror/language", to: "@codemirror--language.js" # @6.12.4
pin "@codemirror/lint", to: "@codemirror--lint.js" # @6.9.7
pin "@codemirror/search", to: "@codemirror--search.js" # @6.7.1
pin "@codemirror/state", to: "@codemirror--state.js" # @6.7.1
pin "@codemirror/view", to: "@codemirror--view.js" # @6.43.6
pin "@lezer/common", to: "@lezer--common.js" # @1.5.2
pin "@lezer/css", to: "@lezer--css.js" # @1.3.4
pin "@lezer/highlight", to: "@lezer--highlight.js" # @1.2.3
pin "@lezer/html", to: "@lezer--html.js" # @1.3.13
pin "@lezer/javascript", to: "@lezer--javascript.js" # @1.5.4
pin "@lezer/lr", to: "@lezer--lr.js" # @1.4.10
pin "@lezer/markdown", to: "@lezer--markdown.js" # @1.7.2
pin "@marijn/find-cluster-break", to: "@marijn--find-cluster-break.js" # @1.0.3
pin "crelt" # @1.0.7
pin "style-mod" # @4.1.3
pin "w3c-keyname" # @2.2.8
