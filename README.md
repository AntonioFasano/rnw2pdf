Rnw2PDF
=======

This is an Emacs library  for [reproducible research](https://yihui.name/knitr/), more specifically: push a key (of your choice) and the [Rnw document](https://raw.githubusercontent.com/yihui/knitr/master/inst/examples/knitr-minimal.Rnw) in your Emacs buffer is converted into a [PDF](https://github.com/yihui/knitr/releases/download/doc/knitr-minimal.pdf) and opened with your PDF viewer. 

See the features to learn more

Features
--------

- _It works in the background_ Start the conversion of the document in your Emacs buffer and keep working on it in Emacs. When done, the viewer will pop up with the PDF. Useful for large/complex documents whose conversion is not immediate.

- _Show me the error!_  If the build process is blocked by an error, a message will appear in the minibuffer to tell what the error was. 

- _Bring me to the error!_  When an error occurs, push a key (of your choice) and Emacs cursor moves to the file and the line where the error occurred. This includes external or generated R/LaTeX files.  

- _Manage citations_ If necessary `bibtex` (or the more recent `biber`) is called to generate bibliographic references.

- _Customise_ Of course you can customise R/LaTeX build commands to fit your taste and the needs of your document. 


- _Dependencies_ There are no Emacs library dependencies. Of course, you need a working R and LaTeX setup on your system.

- _Linux and Windows_ The library code is intended to work with both Linux and Windows. Currently only Windows has been tested. 





Prerequisites
-------------

Of course, you need a working [R](https://www.r-project.org/) and LaTeX distribution. Specifically, make sure that your LaTeX distribution comes with  [latexmk](https://ctan.org/pkg/latexmk/), which should be the case with major distros,  such as [MiKTeX](https://miktex.org/) or 
[TeX Live](https://www.tug.org/texlive/). 

As regards, R to have the Rnw knitted, you need to have the [knitr library](https://yihui.name/knitr) intalled

I have tested this package  with Windows [MiKTeX](https://miktex.org/) and Linux  [TeX Live](https://www.tug.org/texlive/). 


This package does not require [ESS](https://ess.r-project.org/), [Polymode](https://polymode.github.io/), while you might find covenient to use them together. 


Setup
-----

**Step 1** Download from GitHub the file `rnw2pdf.el` and put it in a directory of your Emacs library [load path](https://www.gnu.org/software/emacs/manual/html_node/elisp/Library-Search.html). You may check the variable `C-h v load-path` to learn about suitable directories.


**Step 2** To load the library at startup, add the following to your [Emacs init file](https://www.gnu.org/software/emacs/manual/html_node/emacs/Init-File.html): 

    (require 'rnw2pdf)


If you want to customise the library for a particular R/LaTeX setup or byte-compile it, read the [Customise](#customise) section.   
In particular, if your system is not Linux or Windows, you  need to customise the variable `rnw2pdf-viewer` with your desired PDF viewer.


Using
-----

Open in Emacs your Rnw document or use the provided in the `test` directory (including bibliography files). Issue the command:

    M-x rnw2pdf 

a PDF will pop up in the chosen viewer. 

If there is an error, you will see it in the minibuffer. You can go to it and fix it using:

    M-x rnw2pdf-go2error

After the build, you can switch to the log buffer with `rnw2pdf-build-log`. Similarly, you can visit the bibliography log file (using the .blg extension) with `rnw2pdf-biblog`. 


__Warning__  Depending on the settings you provided, two auxiliary files with the same path as the Rnw document, but extension `.r2p` and `.fls` are generated (and possibly removed as part of a cleaning routine).  Any file with the same path would be overwritten.  If you have such files such files in the directory of the Rnw document, rename or move them elsewhere  to avoid losing their content.




Customise
---------

__Byte-Compile__. You may byte-compile the Rnw2PDF library to improve speed. However for the best part the speed depends on the use of external R/LaTeX tools.   
To compile the library open the`rnw2pdf.el` file in Emacs and issue: 

    M-x byte-compile-file
	
followed by `rnw2pdf.el`. A compiled version of the file is produced in the same directory with the extension `.elc`.

__Custom Paths__  
For an ordinary 64-bit R/LaTeX setup Rnw2PDF is able to find automatically the needed external binaries. However, you might have a non-standard setup, more versions of R/LaTeX or you might want to use a PDF viewer other than the default TeXworks. In that case, read on. 

To instruct Rnw2PDF about which directories LaTeX or R binaries are found, add  a line similar to the following to your Emacs init file: 

    (setq rnw2pdf-search-path "C:/Program Files/MiKTeX 2.9/miktex/bin/x64;C:/Program Files/R/R-3.5.0")

Note that the directory  paths have to be separated by a semicolon `;` in Windows and by a colon `:` in Linux. The only needed R binary is `Rscript`. As regards LaTeX, `latexmk` is always needed, others depend on your document, for example `pdflatex` and `biber`. 

To specify the path of the `Rscript` executable, you can also use the variable: 


    (setq rnw2pdf-r-path "C:/Program Files/R/R-3.1.2/bin/x64/Rscript.exe")

If an `Rscript` executable is found in a directory listed in `rnw2pdf-search-path` and the path you set with `rnw2pdf-r-path` is valid too, the latter is preferred.


In Linux and Windows, the package sets the default PDF application as viewer. In Windows, if available, MiKTeX `texworks` is the preferred default. For other systems or if you don't like the defaults, you can customise the variable `rnw2pdf-viewer`, e.g. by adding a line similar to the following to your Emacs init file: 

    (setq rnw2pdf-viewer "C:/SumatraPDF/SumatraPDF.exe")

Adjust the path  `C:/SumatraPDF/SumatraPDF.exe` as per your favourite viewer. The absolute path is necessary only if the viewer executable, here `Sumatra.exe`, is not in your search path.

_Notes for Linux paths_
Variables can have paths with spaces. Specifically in Linux, spaces will be escaped, that is `/some dir` is added automatically converted to `/some\ dir`. So, don't do this yourself.



_Aux Files_

By default Rnw2PDF stores LaTeX aux files in the  directory `aux-files` relative to the Rnw document. These files act like a cache to speed up successive LaTeX builds. Grouping them in a directory makes it simpler to remove them when you are finished. You can customise the aux directory as desired or set it to `nil` to avoid using it using:

    (setq rnw2pdf-aux "my-aux-files")

The latexmk tool generates a `.fls` file in the Rnw document directory, which is deleted at the end of the build. To keep it use:

    (setq rnw2pdf-clean-fls nil)

However a copy of this file is available in the aux directory, if used.


_Environment variables_

R/LaTeX subprocesses (e.g. Rscript) will inherit environment variables set by Emacs.  
You can use Emacs `setenv` command to set/modify environment variables.  
Contrary to Linux, Windows does not use the environment variable `HOME` to store user profile data, but it uses the variable `USERPROFILE`. Unless otherwise set, Emacs and R both set the environment variable `HOME`, to different values. This affects the visibility of R libraries. To avoid this conflict, Rnw2PDF unsets the  `HOME` variable before running the build processes and restores it immediately after. Perhaps you want to set a particular value for `HOME` in Emacs and don't want Rnw2PDF to unset it, then use:

    (setq  rnw2pdf/no-win-home nil)

This variable's value is only effective under Windows.



Troubleshooting 
---------------

Do you have a working R setup?  
Which is the path of the  `Rscript` executable?  
Find `Rscript` absolute path and set the variable `rnw2pdf-r-path` accordingly.


Are LaTeX executables in your search path?  
If they are not you can modify the system `PATH` variable or add the directories containing LaTeX executables to the variable `rnw2pdf-search-path`

Does your LaTeX system include `latexmk`?  
It is part of the major distributions, such as MiKTeX and TeX Live. If you haven't installed it, do it. If it is installed in an unconventional directory add it to system search path or to the variable `rnw2pdf-search-path`.


Knitting and LaTeXing manually works, Rnw2PDF does not.  
For example I get in Rnw2PDF a library not found error.  
One possibility is that you have more R/LaTeX distros. The ones found automatically Rnw2PDF are not the same you run manually. Check/set the variables 
 `rnw2pdf-r-path` and `rnw2pdf-search-path` to fix this problem. 


	

<!--  LocalWords:  Rnw2PDF Rnw LaTeX minibuffer bibtex biber latexmk
 -->
<!--  LocalWords:  executables init TeXworks MiKTeX Rscript
 -->
