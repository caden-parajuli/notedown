import std / [os, sugar, strutils, browsers, algorithm, times]


import markdown
import karax / [karaxdsl, vdom]

from jester import nil
import jester except serve
       
var files: seq[string]
const
  months: array[12, string] = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
  mathjax = r"""<script>
MathJax = {
  loader: {load: ['[tex]/configmacros']},
  tex: {
    inlineMath: [['$', '$'], ['\\(', '\\)']],
    macros: {
      br: '\\mathbb{R}',
      vep: '{\\varepsilon}',
      abs: ['\\left\\mid #1 \\right\\mid', 1],
      grad: '\\nabla'
    }
  }
};
</script>
<script type="text/javascript" id="MathJax-script" async
  src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js">
</script>"""
  bootstrap = r"""<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha3/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-KK94CHFLLe+nY2dmCWGMq91rCGa5gtU4mk92HdvYe+M/SXH301p5ILy+dN9+nJOZ" crossorigin="anonymous">
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha3/dist/js/bootstrap.bundle.min.js" integrity="sha384-ENjdO4Dr2bkBIFxQpeoTz1HIcje39Wm4jDKdf19U8gI4ddQ3GYNS7NTKfAdVQSZe" crossorigin="anonymous"></script>"""
  highlight = r"""<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.8.0/build/styles/stackoverflow-dark.min.css">
<script src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.8.0/build/highlight.min.js"></script>

<!-- and it's easy to individually load additional languages -->
<script src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.8.0/build/languages/nim.min.js"></script>
<script src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.8.0/build/languages/java.min.js"></script>
<script src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.8.0/build/languages/python.min.js"></script>

<script>hljs.highlightAll();</script>"""
  custom_css = r"<style type='text/css'> body {margin: 20px;} @media (min-width: 200px) { body { padding-top: 65px; } } .my-btn-class {width: 90px !important;} </style>"
  navbarClass = "navbar bg-body-tertiary fixed-top justify-content-between"

template kxi(): int = 0
template addEventHandler(n: VNode; k: EventKind; action: string; kxi: int) =
  n.setAttr($k, action)
  
proc index(fileSeq: seq[string]): string =
  let vnode = buildHtml(html(data-bs-theme = "dark")):
    head:
      title:
        text "Notes"
      verbatim(bootstrap)
      verbatim(custom_css)
    body:
      nav(class = navbarClass):
        a(href = fileSeq[0], class = "btn btn-primary my-btn-class"):
          text "First"
        a(href = "/", class="btn btn-primary"):
          text "Main Menu"
        a(href = fileSeq[fileSeq.high], class = "btn btn-primary my-btn-class"):
          text "Last"
      br()
      tdiv:
        for file in fileSeq:
          a(href = file):
            text file
          br()
  result = $vnode

proc markdownFileToHtml(name, previous, next: string): string =
  let vnode = buildHtml(html(data-bs-theme = "dark")):
    head:
      title:
        text name
      verbatim(mathjax)
      verbatim(bootstrap)
      verbatim(highlight)
      verbatim(custom_css)
    body:
      nav(class = navbarClass):
        a(href = previous, class = "btn btn-primary my-btn-class"):
          text "Previous"
        a(href = "/", class = "btn btn-primary"):
          text "Main Menu"
          br()
        a(href = next, class = "btn btn-primary my-btn-class"):
          text "Next"
      br()
      verbatim(markdown(readFile(name)))
  result = $vnode

proc note_cmp(x, y: string): int =
  let
    fileX = extractFilename(x)
    fileY = extractFilename(y)
    (x_month, x_day) = (fileX[0..2], parseInt(fileX.split("_")[1]))
    (y_month, y_day) = (fileY[0..2], parseInt(fileY.split("_")[1]))
    x_month_num = months.find(x_month)
    y_month_num = months.find(y_month)
  if x_month_num == -1:
    return 1
  elif y_month_num == -1:
    return -1
  result = cmp(x_month_num, y_month_num)
  if result == 0:
    result = cmp(x_day, y_day)

proc parseDate(strDate: string): DateTime =
  result = parse(strDate, "MMM'_'d'_'ddd")
      
proc html(outdir: string = "notedown_html", args: seq[string]) =
  # NOT FINISHED
  var
    inDir: string
      
  if len(args) > 0:
    inDir = args[0]
  else:
    stdout.write "Type the path containing the notes files > "
    inDir = expandTilde(readLine(stdin))
  setCurrentDir(inDir)

  # Create the output directory if it doesn't exist
  createDir(outdir)

  for file in walkDirRec(inDir, relative = true, checkDir = true):
    # If it's a dir, create dir
    if dirExists(inDir / file):
      createDir(outdir / file)
    elif fileExists(inDir / file) and file.splitFile()[2] == ".md":
      files.add(changeFileExt(file, "html"))

  # Sort files (not implemented yet)
  files.sort(note_cmp)
  # Create the index
  writeFile(outdir / "index.html", index(files))
      
  var
    next: string
    previous: string
  for fileNum in 0 .. files.high:
    if fileNum == 0:
      previous = "index.html"
      next = files[1]
    elif fileNum == files.high:
      previous = files[^2]
      next = "index.html"
    else:
      previous = files[fileNum - 1]
      next = files[fileNum + 1]
    writeFile(outDir / files[fileNum], markdownFileToHtml(changeFileExt(files[fileNum], "md"), previous, next))
  

jester.router myRouter:
  get "/":
    jester.resp(index(files))
  post "/":
    jester.resp(index(files))
    
  get "/@name":
    let
        file_index = files.find(@"name")
    if file_index != -1:
      let
        previous = (if file_index == 0: "/" else: files[file_index - 1])
        next = (if file_index == high(files): "/" else: files[file_index + 1])
      var html = markdownFileToHtml(@"name", previous, next)
      resp(html)
    else:
      resp Http404, "ERROR 404: File not found!"
    
proc serve(args: seq[string]) =
  let
    port_num = 8080
    port = Port(port_num)
    my_settings = newSettings(port=port)
  var
    jester_inst = initJester(myRouter, settings=my_settings)
    folder_path: string
      
  if len(args) > 0:
    folder_path = args[0]
  else:
    stdout.write "Type the path containing the notes files > "
    folder_path = expandTilde(readLine(stdin))
  setCurrentDir(folder_path)

  files = collect:
    for file_path in walkFiles("*.md"):
      file_path

  files.sort(note_cmp)
      
  openDefaultBrowser("http://127.0.0.1:" & $port_num)
  jester.serve(jester_inst)

  
when isMainModule:
  import cligen

  # Parse command line
  dispatchMulti([serve], [html])
