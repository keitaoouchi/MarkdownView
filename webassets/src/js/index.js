import hljs from "highlight.js/lib/core";
import MarkdownIt from "markdown-it";
import { full as emoji } from "markdown-it-emoji";
import "./../css/bootstrap.css";
import "./../css/gist.css";
import "./../css/github.css";
import "./../css/index.css";

// highlight.js — 113 languages (selective import)
import ada from "highlight.js/lib/languages/ada";
import apache from "highlight.js/lib/languages/apache";
import applescript from "highlight.js/lib/languages/applescript";
import arduino from "highlight.js/lib/languages/arduino";
import armasm from "highlight.js/lib/languages/armasm";
import asciidoc from "highlight.js/lib/languages/asciidoc";
import aspectj from "highlight.js/lib/languages/aspectj";
import autohotkey from "highlight.js/lib/languages/autohotkey";
import awk from "highlight.js/lib/languages/awk";
import bash from "highlight.js/lib/languages/bash";
import bnf from "highlight.js/lib/languages/bnf";
import c from "highlight.js/lib/languages/c";
import clojure from "highlight.js/lib/languages/clojure";
import clojureRepl from "highlight.js/lib/languages/clojure-repl";
import cmake from "highlight.js/lib/languages/cmake";
import coffeescript from "highlight.js/lib/languages/coffeescript";
import coq from "highlight.js/lib/languages/coq";
import cpp from "highlight.js/lib/languages/cpp";
import crystal from "highlight.js/lib/languages/crystal";
import csharp from "highlight.js/lib/languages/csharp";
import css from "highlight.js/lib/languages/css";
import d from "highlight.js/lib/languages/d";
import dart from "highlight.js/lib/languages/dart";
import delphi from "highlight.js/lib/languages/delphi";
import diff from "highlight.js/lib/languages/diff";
import django from "highlight.js/lib/languages/django";
import dns from "highlight.js/lib/languages/dns";
import dockerfile from "highlight.js/lib/languages/dockerfile";
import dos from "highlight.js/lib/languages/dos";
import ebnf from "highlight.js/lib/languages/ebnf";
import elixir from "highlight.js/lib/languages/elixir";
import elm from "highlight.js/lib/languages/elm";
import erb from "highlight.js/lib/languages/erb";
import erlang from "highlight.js/lib/languages/erlang";
import erlangRepl from "highlight.js/lib/languages/erlang-repl";
import excel from "highlight.js/lib/languages/excel";
import fortran from "highlight.js/lib/languages/fortran";
import fsharp from "highlight.js/lib/languages/fsharp";
import gcode from "highlight.js/lib/languages/gcode";
import gherkin from "highlight.js/lib/languages/gherkin";
import glsl from "highlight.js/lib/languages/glsl";
import go from "highlight.js/lib/languages/go";
import gradle from "highlight.js/lib/languages/gradle";
import groovy from "highlight.js/lib/languages/groovy";
import haml from "highlight.js/lib/languages/haml";
import handlebars from "highlight.js/lib/languages/handlebars";
import haskell from "highlight.js/lib/languages/haskell";
import haxe from "highlight.js/lib/languages/haxe";
import http from "highlight.js/lib/languages/http";
import ini from "highlight.js/lib/languages/ini";
import java from "highlight.js/lib/languages/java";
import javascript from "highlight.js/lib/languages/javascript";
import json from "highlight.js/lib/languages/json";
import julia from "highlight.js/lib/languages/julia";
import kotlin from "highlight.js/lib/languages/kotlin";
import latex from "highlight.js/lib/languages/latex";
import less from "highlight.js/lib/languages/less";
import lisp from "highlight.js/lib/languages/lisp";
import llvm from "highlight.js/lib/languages/llvm";
import lua from "highlight.js/lib/languages/lua";
import makefile from "highlight.js/lib/languages/makefile";
import markdownLang from "highlight.js/lib/languages/markdown";
import mathematica from "highlight.js/lib/languages/mathematica";
import matlab from "highlight.js/lib/languages/matlab";
import nginx from "highlight.js/lib/languages/nginx";
import nim from "highlight.js/lib/languages/nim";
import nix from "highlight.js/lib/languages/nix";
import objectivec from "highlight.js/lib/languages/objectivec";
import ocaml from "highlight.js/lib/languages/ocaml";
import perl from "highlight.js/lib/languages/perl";
import pgsql from "highlight.js/lib/languages/pgsql";
import php from "highlight.js/lib/languages/php";
import phpTemplate from "highlight.js/lib/languages/php-template";
import plaintext from "highlight.js/lib/languages/plaintext";
import powershell from "highlight.js/lib/languages/powershell";
import processing from "highlight.js/lib/languages/processing";
import prolog from "highlight.js/lib/languages/prolog";
import properties from "highlight.js/lib/languages/properties";
import protobuf from "highlight.js/lib/languages/protobuf";
import puppet from "highlight.js/lib/languages/puppet";
import python from "highlight.js/lib/languages/python";
import pythonRepl from "highlight.js/lib/languages/python-repl";
import qml from "highlight.js/lib/languages/qml";
import r from "highlight.js/lib/languages/r";
import reasonml from "highlight.js/lib/languages/reasonml";
import ruby from "highlight.js/lib/languages/ruby";
import rust from "highlight.js/lib/languages/rust";
import sas from "highlight.js/lib/languages/sas";
import scala from "highlight.js/lib/languages/scala";
import scheme from "highlight.js/lib/languages/scheme";
import scss from "highlight.js/lib/languages/scss";
import shell from "highlight.js/lib/languages/shell";
import smalltalk from "highlight.js/lib/languages/smalltalk";
import smali from "highlight.js/lib/languages/smali";
import sql from "highlight.js/lib/languages/sql";
import stata from "highlight.js/lib/languages/stata";
import stylus from "highlight.js/lib/languages/stylus";
import swift from "highlight.js/lib/languages/swift";
import tcl from "highlight.js/lib/languages/tcl";
import thrift from "highlight.js/lib/languages/thrift";
import twig from "highlight.js/lib/languages/twig";
import typescript from "highlight.js/lib/languages/typescript";
import vala from "highlight.js/lib/languages/vala";
import vbnet from "highlight.js/lib/languages/vbnet";
import vbscript from "highlight.js/lib/languages/vbscript";
import vbscriptHtml from "highlight.js/lib/languages/vbscript-html";
import verilog from "highlight.js/lib/languages/verilog";
import vhdl from "highlight.js/lib/languages/vhdl";
import vim from "highlight.js/lib/languages/vim";
import wasm from "highlight.js/lib/languages/wasm";
import x86asm from "highlight.js/lib/languages/x86asm";
import xml from "highlight.js/lib/languages/xml";
import yaml from "highlight.js/lib/languages/yaml";

hljs.registerLanguage('ada', ada);
hljs.registerLanguage('apache', apache);
hljs.registerLanguage('applescript', applescript);
hljs.registerLanguage('arduino', arduino);
hljs.registerLanguage('armasm', armasm);
hljs.registerLanguage('asciidoc', asciidoc);
hljs.registerLanguage('aspectj', aspectj);
hljs.registerLanguage('autohotkey', autohotkey);
hljs.registerLanguage('awk', awk);
hljs.registerLanguage('bash', bash);
hljs.registerLanguage('bnf', bnf);
hljs.registerLanguage('c', c);
hljs.registerLanguage('clojure', clojure);
hljs.registerLanguage('clojure-repl', clojureRepl);
hljs.registerLanguage('cmake', cmake);
hljs.registerLanguage('coffeescript', coffeescript);
hljs.registerLanguage('coq', coq);
hljs.registerLanguage('cpp', cpp);
hljs.registerLanguage('crystal', crystal);
hljs.registerLanguage('csharp', csharp);
hljs.registerLanguage('css', css);
hljs.registerLanguage('d', d);
hljs.registerLanguage('dart', dart);
hljs.registerLanguage('delphi', delphi);
hljs.registerLanguage('diff', diff);
hljs.registerLanguage('django', django);
hljs.registerLanguage('dns', dns);
hljs.registerLanguage('dockerfile', dockerfile);
hljs.registerLanguage('dos', dos);
hljs.registerLanguage('ebnf', ebnf);
hljs.registerLanguage('elixir', elixir);
hljs.registerLanguage('elm', elm);
hljs.registerLanguage('erb', erb);
hljs.registerLanguage('erlang', erlang);
hljs.registerLanguage('erlang-repl', erlangRepl);
hljs.registerLanguage('excel', excel);
hljs.registerLanguage('fortran', fortran);
hljs.registerLanguage('fsharp', fsharp);
hljs.registerLanguage('gcode', gcode);
hljs.registerLanguage('gherkin', gherkin);
hljs.registerLanguage('glsl', glsl);
hljs.registerLanguage('go', go);
hljs.registerLanguage('gradle', gradle);
hljs.registerLanguage('groovy', groovy);
hljs.registerLanguage('haml', haml);
hljs.registerLanguage('handlebars', handlebars);
hljs.registerLanguage('haskell', haskell);
hljs.registerLanguage('haxe', haxe);
hljs.registerLanguage('http', http);
hljs.registerLanguage('ini', ini);
hljs.registerLanguage('java', java);
hljs.registerLanguage('javascript', javascript);
hljs.registerLanguage('json', json);
hljs.registerLanguage('julia', julia);
hljs.registerLanguage('kotlin', kotlin);
hljs.registerLanguage('latex', latex);
hljs.registerLanguage('less', less);
hljs.registerLanguage('lisp', lisp);
hljs.registerLanguage('llvm', llvm);
hljs.registerLanguage('lua', lua);
hljs.registerLanguage('makefile', makefile);
hljs.registerLanguage('markdown', markdownLang);
hljs.registerLanguage('mathematica', mathematica);
hljs.registerLanguage('matlab', matlab);
hljs.registerLanguage('nginx', nginx);
hljs.registerLanguage('nim', nim);
hljs.registerLanguage('nix', nix);
hljs.registerLanguage('objectivec', objectivec);
hljs.registerLanguage('ocaml', ocaml);
hljs.registerLanguage('perl', perl);
hljs.registerLanguage('pgsql', pgsql);
hljs.registerLanguage('php', php);
hljs.registerLanguage('php-template', phpTemplate);
hljs.registerLanguage('plaintext', plaintext);
hljs.registerLanguage('powershell', powershell);
hljs.registerLanguage('processing', processing);
hljs.registerLanguage('prolog', prolog);
hljs.registerLanguage('properties', properties);
hljs.registerLanguage('protobuf', protobuf);
hljs.registerLanguage('puppet', puppet);
hljs.registerLanguage('python', python);
hljs.registerLanguage('python-repl', pythonRepl);
hljs.registerLanguage('qml', qml);
hljs.registerLanguage('r', r);
hljs.registerLanguage('reasonml', reasonml);
hljs.registerLanguage('ruby', ruby);
hljs.registerLanguage('rust', rust);
hljs.registerLanguage('sas', sas);
hljs.registerLanguage('scala', scala);
hljs.registerLanguage('scheme', scheme);
hljs.registerLanguage('scss', scss);
hljs.registerLanguage('shell', shell);
hljs.registerLanguage('smalltalk', smalltalk);
hljs.registerLanguage('smali', smali);
hljs.registerLanguage('sql', sql);
hljs.registerLanguage('stata', stata);
hljs.registerLanguage('stylus', stylus);
hljs.registerLanguage('swift', swift);
hljs.registerLanguage('tcl', tcl);
hljs.registerLanguage('thrift', thrift);
hljs.registerLanguage('twig', twig);
hljs.registerLanguage('typescript', typescript);
hljs.registerLanguage('vala', vala);
hljs.registerLanguage('vbnet', vbnet);
hljs.registerLanguage('vbscript', vbscript);
hljs.registerLanguage('vbscript-html', vbscriptHtml);
hljs.registerLanguage('verilog', verilog);
hljs.registerLanguage('vhdl', vhdl);
hljs.registerLanguage('vim', vim);
hljs.registerLanguage('wasm', wasm);
hljs.registerLanguage('x86asm', x86asm);
hljs.registerLanguage('xml', xml);
hljs.registerLanguage('yaml', yaml);

let markdown = new MarkdownIt({
  html: true,
  breaks: true,
  linkify: true,
  highlight: function (code) {
    return hljs.highlightAuto(code).value;
  },
});

const postDocumentHeight = () => {
  var _body = document.body;
  var _html = document.documentElement;
  var height = Math.max(
    _body.scrollHeight,
    _body.offsetHeight,
    _html.clientHeight,
    _html.scrollHeight,
    _html.offsetHeight
  );
  console.log(height)
  window?.webkit?.messageHandlers?.updateHeight?.postMessage(height);
};

markdown.use(emoji);

window.usePlugin = (plugin) => markdown.use(plugin);

window.showMarkdown = (percentEncodedMarkdown, enableImage = true) => {
  if (!percentEncodedMarkdown) {
    return;
  }

  const markdownText = decodeURIComponent(percentEncodedMarkdown);

  if (!enableImage) {
    markdown = markdown.disable("image");
  }

  let html = markdown.render(markdownText);

  document.getElementById("contents").innerHTML = html;

  var imgs = document.querySelectorAll("img");

  imgs.forEach((img) => {
    img.loading = "lazy";
    img.onload = () => {
      postDocumentHeight();
    };
  });

  window.imgs = imgs;

  let tables = document.querySelectorAll("table");

  tables.forEach((table) => {
    table.classList.add("table");
  });

  let codes = document.querySelectorAll("pre code");

  codes.forEach((code) => {
    hljs.highlightElement(code);
  });

  postDocumentHeight();
};
