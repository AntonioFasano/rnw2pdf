;;; -*- lexical-binding: t -*-
; debug
; (setq rnw2pdf-r-path "c:/binp/R/app/bin/Rscript.exe")
; (setq rnw2pdf/rnw-alist nil)
; (setq rnw2pdf-viewer "c:/binp/SumatraPDF/Sumatra PDF.exe")
; (setq rnw2pdf-search-path "c:\\binp\\R\\app\\bin")
; (setq rnw2pdf-search-path nil)
; (setq rnw2pdf/r-cmd "%r %k %R")
					
; (setq rnw2pdf-r-path nil)

;;; NOTES
;; Test Process buffer killed by user in sentinel during a long build
;; Review (defun ordinary-insertion-filter
;; Review update modeline with process status

;;; Viewers
;; MiKTeX
;; texworks main.pdf
;; PDF-XChange Viewer
;; pdfxcview /A "nolock=yes=OpenParameters" test.pdf
;; Sumatra powershell 
;; latexmk -e '"$pdf_previewer=q|start C:/ProgramData/chocolatey/bin/SumatraPDF.exe %O %S|"' -pdf -pv foo
;; Sumatra cmd 											          
;; latexmk -e  "$pdf_previewer=q|start C:/ProgramData/chocolatey/bin/SumatraPDF.exe %O %S|"  -pdf -pv foo
;; Sumatra bash											          
;; latexmk -e  '$pdf_previewer=q|start C:/ProgramData/chocolatey/bin/SumatraPDF.exe %O %S|'  -pdf -pv foo

;; PDF
;; latexmk -interaction=nonstopmode -file-line-error -output-directory=aux-files -pdf -shell-escape -silent -g main
;; %l -interaction=nonstopmode -file-line-error -output-directory=aux-files -pdf -shell-escape -silent -g %f

;; AUCTeX refs
;; tex-buf:
;; TeX-error,TeX-parse-error
;; TeX-run-command
;; TeX-command-sentinel
;; TeX-command-filter
;; TeX-expand-list-builtin examples


;;; User vars
;;; =========
(defvar rnw2pdf-r-path nil
  "Path to Rscript executable. It can be the absolute path of the executable or its  name if it can be found in the search path. In the latter case see also `rnw2pdf-search-path'. 
It defaults to `Rscript'.")

(defvar rnw2pdf-viewer
  (cond
   ((eq system-type 'windows-nt)
    (if (executable-find "texworks")
	"texworks"
      (let ((app (shell-command-to-string "cmd /c assoc .pdf")))
	(setq app (cadr (split-string app "=")))
	(when app
	  (setq app (shell-command-to-string (concat "cmd /c ftype " app)))
	  (setq app (cadr (split-string app "=")))
	  (setq app (nth 1 (split-string app "\"")))))))

   ((and (eq system-type 'gnu/linux)
	 (executable-find "xdg-open"))
    (substring  
     (shell-command-to-string "basename $(xdg-mime query default application/pdf) .desktop") 0 -1))

   (t nil))
  
  "Path to PDF viewer. In Windows defaults to MiKTeX `texworks' or alternatively to the default PDF application. In Linux defaults to the default PDF application. For other systems or when there is no suitable application, it is nil.")

(defvar rnw2pdf-search-path nil
  "Directory path or list directory paths to search for excutables such as latexmk, pdflatex. If nil, the enviroment variable PATH is used; otherwise the added paths are sought before. This variable is also used to find the R executable when `rnw2pdf-r-path' is not an absolute path.")

(defvar rnw2pdf-aux "aux-files"
  "Temporary file directory.")

;;;;; Not used after swtiching from -auxdir to -output-directory 
(defvar rnw2pdf-clean-fls t
  "If non-nil, the latexmk \".fls\" file in the Rnw document directory is deleted at the end of the build. 
Note that if `rnw2pdf-aux' is non-nil, a copy of this file is available in the aux directory.")

(defvar rnw2pdf/inherit-home nil 
  "If your system is Windows, nil unsets Emacs \"HOME\" environment variable for called subprocesses. 
In Windows, there is no systen set \"HOME\" variable. Some progrmas set themselves the value of this variable, unless the user has already done so. R and Emacs set different values for it. When we call R as an Emacs subprocess, it will inherit the wrong value. For this reason it is better to disable \"HOME\" inheritance.")



;;; Global vars 
;;; ===========

(defvar rnw2pdf/r-cmd "%r %k %R"
  "Command template to process (knit) Rnw file.
`%string' are expanded according to `rnw2pdf/expand-list'.")

(defvar rnw2pdf/tex-cmd "%l -interaction=nonstopmode -pdf -shell-escape -silent -g %f"
  "Command template to process TeX file.
`%string' are expanded according to `rnw2pdf/expand-list'.")

(defvar rnw2pdf/view-cmd "%v %p"
  "Command template to view PDF file.
`%string' are expanded according to `rnw2pdf/expand-list'.")

(defconst rnw2pdf/original-exec-path exec-path
  "Used to restore `exec-path' value after adding the directories in `rnw2pdf-search-path'.")

(defconst rnw2pdf/job-seq (list 'knit 'latex 'view 'dispose) 
  "List of sub-jobs involved involved in Rnw building.")

(defvar rnw2pdf/rnw-alist nil
  "Alist associating Rnw document paths to the process buffers (receiving the input of building commands).")

(defvar rnw2pdf/sys-shell
  (if (eq system-type 'windows-nt)
      shell-file-name
    "/bin/sh")
  "Full path of system shell. Under Windows normally it is `cmdproxy.exe'")

(defvar rnw2pdf/expand-list
  '(;; quoted file.rnw stem 
    ("%f" (lambda (rnw-path-sans)
	    (shell-quote-argument rnw-path-sans)))
    ;; quoted file.Rnw
    ("%R" (lambda (rnw-path-sans)
	    (shell-quote-argument (concat rnw-path-sans ".Rnw"))))    
    ;; quoted file.pdf
    ("%p" (lambda (rnw-path-sans)
	    (shell-quote-argument (concat rnw-path-sans ".pdf"))))    
    ;; quoted file.r2p containing knit code
    ("%k" (lambda (rnw-path-sans)
	    (shell-quote-argument (rnw2pdf/set-r2p-path rnw-path-sans))))    
    ;; R executable
    ("%r" (lambda (dummy)
	    (rnw2pdf/r-path)))
    ;; LaTeX executable (latexmk)
    ("%l" (lambda (dummy)
	    "latexmk"))
    ;; Viewer executable (latexmk)
    ("%v" (lambda (dummy)
	    (shell-quote-argument rnw2pdf-viewer))))

  "List \"expansion strings\" and associated hook functions for rnw2pdf command strings.
Before running a command string, expansion strings are expanded with the output of the hook functions.
Hook functions should be added as one-argument lambdas. Always add the argument to lambdas, even if it is unused")

;; Variables local to process buffer.
;; See `rnw2pdf/make-proc-buf'
;; ----------------------------------

(defvar-local associated-rnw-path nil
"Rnw absolute document path. 
Note that the process buffer is not associated to a file unless the user saves it.")

(defvar-local next-job
  "Next job to carry out. Can be: 'knit, 'latex or 'dispose. The latter involves resetting process buffer local variables")

(defvar-local is-active nil
  "Nil if no build is happening, so no process is running and local variables are reset for the related process buffer.")

(defvar-local error-p nil
  "Non-nil if an error has been detected during the build.")

(defvar-local error-line-beg nil
  "The beginning line of the error `error-file' or nil.")

(defvar-local error-line-end nil
  "The ending line of the error `error-file' or nil. 
Not used for TeX errors")

(defvar-local error-file nil
  "File with the build errors or nil.")


;;; Main 
(defun rnw2pdf ()
  "Convert the Rnw document in the current buffer in a PDF a display it with the TeXworks viewer, unless a different one is configured.
The file is automatically saved if it is associated to a file, otherwise the user is asked to save it.
It is required for the file to have a \".Rnw\" extension."
  (interactive)
  (let ((rnw-path (buffer-file-name))
	err)
    
    (setq err (catch 'rnw2pdf/main
		(rnw2pdf/set-exec-path t)                     ; temporary adapt search PATH to user var
		(rnw2pdf/distro-test)                         ; test R/LaTeX tools
		(rnw2pdf/file-save)                           ; save or ask to save Rnw buffer
		(rnw2pdf/active-job? rnw-path)                ; active build job running?
		(rnw2pdf/make-proc-buf rnw-path)              ; init process buffer and local vars
		(rnw2pdf/make-knit-script rnw-path)           ; make .r2p scripts
		(rnw2pdf/next-job rnw-path)                     ; re-called by sentinel 'till queue is empty 
		(message "Processing...")))                   ; 'till sentinel says otherwise	  
    (rnw2pdf/set-exec-path nil)                               ; restore search PATH
    (if err (message err))))
    
(defun rnw2pdf/next-job (rnw-path)
  "Execute the job set by the variable `next-job' local to the process buffer identified by RNW-PATH.
`rnw2pdf/command-sentinel' updates `next-job' and re-call this function until the local variable is empty.
Depending on the job, `rnw2pdf/r-cmd' or `rnw2pdf/tex-cmd' command patterns are (exapndend and) executed."

  (let* ((proc-buf (rnw2pdf/get-pbuf rnw-path)) 
	 (next-job (buffer-local-value 'next-job proc-buf))
	 command cmd-template job-desc process)
    
    ;; Set current items
    (set-buffer proc-buf)                   ; process buffer current 
    (cd (file-name-directory rnw-path))     ; cd Rnw doc

    ;; Get job
    (setq job-desc (pcase next-job
		     ('knit  "Knitting")
		     ('latex "Latexing")
		     ('view  "Viewing")
		     ('dispose "Finished processing"))

	  cmd-template (pcase next-job
			 ('knit  rnw2pdf/r-cmd)
			 ('latex rnw2pdf/tex-cmd)
			 ('view rnw2pdf/view-cmd) 
			 ('dispose "rnw2pdf")))

    ;; Add cmd template customisations 
    (setq cmd-template (rnw2pdf/customise-template next-job cmd-template))
    ;; Expand cmd template 
    (setq command (rnw2pdf/command-expand cmd-template proc-buf))
    (insert job-desc " " rnw-path " with:\n" command "\n\n")
    (goto-char (point-max))
      
    (let
	;; Possibly remove $HOME inheritance
	((emacs-home (getenv "HOME"))
	 (no-home-p (and (eq system-type 'windows-nt) (not rnw2pdf/inherit-home)))
	 (def-dir default-directory))	
      (setq default-directory (file-truename  def-dir)) ;Expand "~" before possibly unset HOME 
      (if no-home-p (setenv "HOME"))


      ;; Execute next job on queue
      (pcase next-job
	('dispose (rnw2pdf/dispose-job proc-buf))

      
	;; Execute process (without sentinels for 'view)
	('view

	 ;; Copy PDF out of aux dir
	 (let*
	     ((out-pdf (rnw2pdf/change-ext rnw-path ".pdf"))
      	      (aux-pdf (concat (file-name-directory out-pdf)     
			       (file-name-as-directory rnw2pdf-aux)
			       (file-name-nondirectory out-pdf))))
	   (copy-file aux-pdf out-pdf t))
       
	 (call-process rnw2pdf/sys-shell nil 0 nil "-c" command)
	 ;; Explicit invocatition of next job for 'view
	 (setq-local next-job 'dispose)
	 (rnw2pdf/next-job rnw-path))


	(_
	 ;; The sentinel will invoke the next job
	 (setq process (start-process job-desc proc-buf rnw2pdf/sys-shell "-c" command))
	 (set-process-filter process #'ordinary-insertion-filter)
	 (set-process-sentinel process #'rnw2pdf/command-sentinel)))

      ;; Restore $HOME 
      (setenv "HOME" emacs-home)
      (setq default-directory def-dir))))


;;; Main Functions
;;; ==============

(defun rnw2pdf/set-exec-path (add)
  "If ADD is non-nil, add the directories in `rnw2pdf-search-path', if any, to `exec-path'. If ADD is nil, restore original search path stored in `rnw2pdf/original-exec-path'."
  (let ((dlist (if (listp rnw2pdf-search-path) rnw2pdf-search-path (list rnw2pdf-search-path))))

    ;;  rnw2pdf-search-path values 
    (when (and add dlist) 
      (mapc #'(lambda (path) (if (not (stringp path))
				 (rnw2pdf/ret (format
					       "ERROR: In `rnw2pdf-search-path'\n%s is not a string."
					       path)))) dlist)
      (mapc #'(lambda (path) (if (not (file-directory-p path))
				 (rnw2pdf/ret (concat "ERROR: In `rnw2pdf-search-path'\n"
						      path "\nnot found.")))) dlist))

    ;; In Linux /spaced path becomes /spaced\ path
    (unless (eq system-type 'windows-nt)
	    (setq dlist (mapcar #'(lambda (path) (shell-quote-argument path)) dlist)))
    
    ;; Add values to path		
    (setq exec-path (if add (append dlist exec-path) rnw2pdf/original-exec-path))))

(defun rnw2pdf/distro-test ()
  "Test needed binaries are available."

  ;; Test R distro working
  (if rnw2pdf-r-path
      ;; r-path is given, but wrong       
      (unless (file-exists-p rnw2pdf-r-path)
	(rnw2pdf/ret (concat "ERROR: " rnw2pdf-r-path "\ndoes not exist or is not executable")))
    ;; r-path not given, but:
    (unless (executable-find "Rscript") ; in PATH
      (unless (setq rnw2pdf-r-path (rnw2pdf-find-r-win)) ; a canonical Win R exists
	(rnw2pdf/ret "ERROR: Cannot find R executable. 
Make sure Rscript executable is in your path or set `rnw2pdf-r-path' variable."))))

  ;; Test PDF viewer
  (if (not rnw2pdf-viewer)
      (rnw2pdf/ret "ERROR: Please set the variable `rnw2pdf-viewer' to the path of a PDF viewer.")
    (unless (or (equal rnw2pdf-viewer "start") (executable-find rnw2pdf-viewer))
      (rnw2pdf/ret
       (format "ERROR: Cannot find PDF viewer executable \n%s\n set by the  variable `rnw2pdf-viewer'."
	       rnw2pdf-viewer))))
    
  ;; Test TeX working
  (unless (and (executable-find "tex")
	       (executable-find "latexmk"))
    (rnw2pdf/ret "ERROR: Cannot find a working TeX distribution with latexmk.
Make sure latexmk and common TeX binaries are found in your PATH environment variable."))

  ;; if no errors, ret success
  t)
  
(defun rnw2pdf/file-save ()
  "Save Rnw document in the current buffer and create knitting script. 
If the current buffer is not associated to a file stop and ask to save."
  (unless buffer-file-name
    (rnw2pdf/ret (concat "ERROR: " (buffer-name) " is not associated to any file. Please, save it using the extension \".Rnw\".")))
  (save-buffer)
  (message "Saved and processing..."))


(defun rnw2pdf/active-job? (rnw-path)
  "Check if there a process buffer associated to RNW-PATH with active build jobs.
If so ask whether to kill the process or abort the request.
The variable `is-active', local to process buffer , is set to nil when the build is finished."

  (let* ((proc-buf (rnw2pdf/get-pbuf rnw-path))
	(prc (get-buffer-process proc-buf))
	yes)

    (when (and proc-buf
	       ;; despite is-active is nil, prc can be a process not properly terminated.
	       (or prc (buffer-local-value 'is-active proc-buf)))
	  (setq yes (yes-or-no-p
		     (format "Process `%s' for document \n%s\nrunning, kill it? "
			     (if prc (process-name prc) "unknown")
			     (buffer-local-value 'associated-rnw-path proc-buf))))
	  (if yes (rnw2pdf/dispose-job proc-buf)
	    (rnw2pdf/ret "ERROR: Cannot have two processes for the same document.")))
    
    (if prc
      (rnw2pdf/ret "ERROR: Cannot kill process!"))))

(defun rnw2pdf/make-proc-buf (rnw-path)
  "Associate and create a process buffer to the RNW-PATH, if it does not exist, and init the following local variables:
  `associated-rnw-path' stores the Rnw document path RNW-PATH. It is used to solve conflicts with existing PROC-BUF-NAME names (see `rnw2pdf/make-proc-buf');
  `is-active' non-nil until the build process is finished;
  `next-job' symbol of the next job to carry out; initialised to 'knit.
The name associated process buffer defined by the funcion `rnw2pdf/make-short-name'."

  ;;Remove killed buffer from the Rnw alist
  (rnw2pdf/remove-killed-buffers)

  (let ((pbuf (rnw2pdf/get-pbuf rnw-path))) ; take only live
    
    ;; Make buffer if none associated with rnw-path 
    (unless pbuf
      (setq pbuf (get-buffer-create (rnw2pdf/make-short-name rnw-path)))
      (push (cons rnw-path pbuf) rnw2pdf/rnw-alist))

    ;; Init local vars
    (with-current-buffer pbuf
      (buffer-disable-undo)
      (erase-buffer)
      (setq-local line-number-display-limit 0)    ; unlimited buffer
      (setq-local associated-rnw-path rnw-path) 
      (setq-local next-job 'knit)
      (setq-local is-active t))))

(defun rnw2pdf/make-knit-script (rnw-path)
  "If missing, create the file with \".r2p\" containing knitting commands. The file has the same stem as the Rnw document RNW-PATH and lives in the same directory."  
  (let ((script-name  (rnw2pdf/set-r2p-path (file-name-sans-extension rnw-path)))
	(script-cont "
library(knitr)
args <- commandArgs(TRUE)
setwd(dirname(args[1]))
getwd()
opts_chunk$set(error = FALSE)
knit(args)"))
    (unless (file-exists-p script-name)
      (make-directory (file-name-directory script-name) t)
      (write-region script-cont nil script-name)))
  t)

(defun rnw2pdf/dispose-job (proc-buf)
  "Delete process and set to nil status variables."
  (let ((process (get-buffer-process proc-buf)))
    (if process (delete-process process)))
  
  (with-current-buffer proc-buf
    (setq-local next-job nil)
    (setq-local is-active nil))

  ;; Remove latexmk fls file ;;;;; Not used after swtiching from -auxdir to -output-directory 
  (if (and rnw2pdf-clean-fls associated-rnw-path)
      (let ((fls (rnw2pdf/change-ext associated-rnw-path ".fls")))
	(if (file-exists-p fls)
	    (delete-file fls)))))



(defun rnw2pdf/command-sentinel (process event)
  "When the process associated with the command called by `rnw2pdf/next-job' changes state, this function is called. It receives two arguments: the process as PROCESS and the string EVENT describing the change. 
The latter is most likely an exit message."
  
  (let* ((proc-buffer (process-buffer process))
	 (proc-name (process-name process))
	 job-pos fail)

    (cond
     ;; Process buffer killed by user 
     ((null proc-buffer)
      (set-process-buffer process nil)
      (set-process-sentinel process nil)
      (message "Sorry, process buffer \n%s\nhas been killed right know. Start again."
	       (buffer-name proc-buffer)))

     ;; Process finished
     ((memq (process-status process) '(signal exit))
      (with-current-buffer proc-buffer

	;; Parse errors
	(setq fail (rnw2pdf/parse-errors process))

	;; Write post-mortem info
	(goto-char (point-max))
	(insert-before-markers "\n" proc-name " " event) ; write exit mess
	(forward-char -1) ; exit at: 
	(insert " at " (substring (current-time-string) 0 -5)) 
	(forward-char 1)
	(message (if fail fail
		   (concat proc-name " " event  "at " (substring (current-time-string) 0 -5))))

	;; Update modeline with process status
	(setq mode-line-process
	      (concat ": " (symbol-name (process-status process))))
	;; Force mode line redisplay soon ??? check
	(set-buffer-modified-p (buffer-modified-p))

	;; Delete the now dead process
	(delete-process process)

	;; Start the new job
	(setq job-pos (cl-position next-job rnw2pdf/job-seq))
	(setq-local next-job
		    (nth (1+ job-pos) rnw2pdf/job-seq))
	(if fail (setq-local next-job 'dispose))
	(rnw2pdf/next-job associated-rnw-path)))    ; end process exit cond
     )))

(defun ordinary-insertion-filter (proc string)
  (when (buffer-live-p (process-buffer proc))
    (with-current-buffer (process-buffer proc)
      (save-excursion
	;; Insert the text, advancing the process marker.
	(goto-char (process-mark proc))
	(insert (replace-regexp-in-string "\r" "\n" string))
;	(insert  string)
	(set-marker (process-mark proc) (point)))
      (goto-char (process-mark proc)))))

;;; end Main Functions ====


;;; Build Helpers
;;; =============

(defun rnw2pdf/command-expand (command proc-buf)
  "Expand COMMAND using `rnw2pdf/expand-list' and local variables in PROC-BUF.  
As a special exception, `%%' can be used to produce a single `%' sign in the output
without further expansion. This function is based on the ideas in `TeX-command-expand'."

  (let* ((rnw-path (buffer-local-value 'associated-rnw-path proc-buf))
	 (rnw-sans (file-name-sans-extension rnw-path))
	 pat match-pos elist-elt %code expansion 
	 (elist (list "%%" (lambda nil
			     (setq match-pos (1+ match-pos)) ; avoid using replaced % with recursion
			     "%"))))
    (setq elist (cons elist rnw2pdf/expand-list)
	  pat (regexp-opt (mapcar #'car elist)))
    (while (setq match-pos (string-match pat command match-pos))
      (setq %code (match-string 0 command)
	    elist-elt (assoc %code elist)
	    expansion (car (cdr elist-elt))
	    %code (save-match-data ; apply expansion might use regex
		    (if expansion
			(funcall expansion rnw-sans) ; rnw-sans only arg used currently 
		      (rnw2pdf/ret (format "In command: %s\n%s is not a valid expansion."
					   command %code)))))
      (if (stringp %code)
	  (setq command
		(replace-match %code t t command)))))
  command)



(defun rnw2pdf/customise-template (job core)
  "Depending on JOB add custom options to CORE template."
  
  (let ((cust ""))
    (pcase job 
      ('latex
       (if rnw2pdf-aux
	   (setq cust (concat cust " -output-directory=" (shell-quote-argument rnw2pdf-aux)))))
;      ('view
      )
      
;       (if rnw2pdf-viewer
; 	   (let ((cmd
; 		  (format
; 		   ;; q|hello| is 'hello' in perl
; 		   "$pdf_previewer=q|start %s %%O %%S|" 
; 		   (shell-quote-argument rnw2pdf-viewer))))
; 
; 	     (setq cmd (if (eq system-type 'windows-nt)  
; 			   ;; Win cmd: perl -e "command"
; 			   (format " -e \"%s\" -pv" cmd)
; 			 
; 			 ;; Linux cmd: perl -e 'command'  
; 			 (format " -e '%s' -pv" cmd)))
; 
; 	     (setq cust (concat cust cmd))))))
    (concat core cust)))
  
(defun rnw2pdf/parse-errors (process)
  "Parse build process errors."

  (with-current-buffer (process-buffer process)
    (pcase next-job
      ('knit
       (rnw2pdf/parse-errors-r process))

      ('latex
	(rnw2pdf/parse-errors-tex process)))))
          
     
(defun rnw2pdf/parse-errors-r (process)
  "Parse knitting errors, possibly setting process buffer local variables `error-file', `error-line-beg', `error-line-end' to non-nil values. Return the error description or nil."
  
  (let (curpos error? err-block r-label r-desc)

    (with-current-buffer (process-buffer process)
      (setq-local error-p nil)
      (setq-local error-line-beg nil)
      (setq-local error-line-end nil)
      (setq-local error-file nil)

      ;; An output file means no error
      (save-excursion
	(setq error? (not (re-search-backward "^output file:.+\n\n\\[1]" nil t))))
	
      (when error?

	(setq error-p t)

	;; get error block 
	(forward-char -1)
	(setq curpos (point))

	(cond 
	 ((re-search-backward "^label: " nil t)
	  (setq err-block (buffer-substring-no-properties (match-beginning 0) curpos))

	  ;; get chunk label
	  (string-match "^label: \\(.+?\\)\\( \\|\n\\)" err-block)
	  (setq r-label (match-string 1 err-block))

	  ;; get error lines (beg/end), file and desck
	  (string-match "^Quitting from lines \\(.+\\)-\\(.+\\) (\\(.+\\)) *\n" err-block )
	  (setq error-line-beg (string-to-number (match-string 1 err-block))
		error-line-end (string-to-number (match-string 2 err-block))
		error-file (match-string 3 err-block)
		r-desc (match-end 0)
		r-desc (substring err-block r-desc))

	  ;; Less noise in desc: remove last 3 lines
	  (setq r-desc (butlast (split-string r-desc "\n") 3))
	  (setq r-desc (mapconcat 'identity r-desc "\n"))
	  
	  (setq r-desc (replace-regexp-in-string "^Error in parse.+ : <text>:" "" r-desc))
	
	  ;; Write error in process buffer
	  (goto-char (point-max))
	  (insert "\n=== ERROR Summary ===\n")
	  (insert "Chunk " r-label " in " error-file "\n")
	  (insert r-desc "")
	  (insert "\n---------------------------------------\n")

	  ;; Error for minibuffer 
	  (setq r-desc (concat r-label " -> " error-file "\n" r-desc)))

	 ((re-search-backward "^Error " nil t)
	  (setq r-desc (buffer-substring-no-properties (match-beginning 0) curpos))

	  ;; Less noise in desc: remove last 1 lines
	  (setq r-desc (butlast (split-string r-desc "\n") 1))
	  (setq r-desc (mapconcat 'identity r-desc "\n")) 
	  (goto-char (point-max)))

	 (t
	  (setq r-desc "Knitting error!")
	  (goto-char (point-max))))
      
	r-desc))))

  
(defun rnw2pdf/parse-errors-tex (process)
  "Parse LaTeX errors, possibly setting process buffer local variables `error-file' and `error-line-beg' to non-nil values. Return the error description or nil.
Error lines in the LaTeX log file are detected by their leading `!'. Unfortunately BibLaTeX backend (but not Biber) might exit non-zero (i.e. signal a fatal error) without writing the error in the LaTeX log file. In this case the user is addressed to inspect the LaTeX bibliography log file by means of `rnw2pdf-biblog'."

  (with-current-buffer (process-buffer process)
    (setq-local error-p nil)
    (setq-local error-line-beg nil)
    (setq-local error-line-end nil)
    (setq-local error-file nil)
	 
    (when (> (process-exit-status process) 0)
      (setq error-p t)
      (let* ((rnw-path (buffer-local-value 'associated-rnw-path (process-buffer process)))
	     (rnw-dir (file-name-directory rnw-path))
	     (aux-dir (file-name-as-directory (expand-file-name rnw2pdf-aux rnw-dir)))
	     (tex-log (expand-file-name
		       (rnw2pdf/change-ext (file-name-nondirectory rnw-path) ".log")
		       aux-dir))
	     
	     (err-file (rnw2pdf/change-ext rnw-path ".tex")) ; default err file
	     !-error ; the LaTeX error (not used by bibtex/biber)
	     err-type err-line-beg err-desc)
	
	(with-temp-buffer
	  (insert-file-contents tex-log)
	  (goto-char (point-max))
	  ;; A leading ! denotes the LaTeX log error lines (but not for blg)
	  (when (setq !-error (re-search-backward "^!.+" nil 'noerror))
	    (setq err-type (substring (match-string 0) 2))
	    (forward-line -1) 
	  
	    ;; If before !-line there is a line like
	    ;; (path
	    ;; without closing parenthesis, path is the error file
	    (when (looking-at "^(\\(.+[^)]$\\)")
	      (setq err-file (match-string 1))
	      (setq err-file (replace-regexp-in-string "\"" "" err-file))
	      (setq err-file (expand-file-name err-file rnw-dir)))
	    (forward-line 2)
	    (looking-at ".+")
	    (setq err-desc (match-string 0))
	    (string-match "\\(.+?\\) \\(.+\\)" err-desc)
	    (setq err-line-beg (replace-regexp-in-string ".\\." "" (match-string 1 err-desc))
		  err-line-beg (string-to-number err-line-beg ))
	    (setq err-desc (match-string 2 err-desc))
	    (forward-line 1) 
	    (if (looking-at "^  +.+")
		(setq err-desc (concat err-desc "\n" (match-string 0))))
	    (setq err-desc (concat err-type "\n" err-desc))
	    (setq-local error-line-beg err-line-beg)
	    (setq-local error-file err-file))

	  (if !-error err-desc	 
	    ;; May be latexmk was stopped by a bibtex citation warning
	    (goto-char (point-min))
	    (if (re-search-forward "Package biblatex Info: Trying to load BibTeX" nil 'noerror)
	      "Apparent BibTeX error. For more info try `M-x rnw2pdf-biblog'"				
	      "Unable to detect error see the log add a function to see it")))))))

;		 (re-search-forward "\\(LaTeX Warning: Citation \\)\\(.+\\)"  nil 'noerror)


(defun rnw2pdf-go2error ()
  "Given the Rnw document buffer, go to last build error, if any."
  (interactive)
  (let* ((rnw-path (buffer-file-name))
	 proc-buf
	 e-file e-beg n)

    (cond     
     ((not rnw-path) (message "This buffer is not associated with a file"))
     ((not (setq proc-buf (rnw2pdf/get-pbuf rnw-path)))
      (message "I can't find build info for the document\n%s\nDid you delete the its process buffer."
	      rnw-path))
     (t
      (with-current-buffer proc-buf
	(setq e-file error-file
	      ;;e-end  error-line-end
	      e-beg  error-line-beg))
    
      (if (not e-file)
	  (if error-p 
	      (switch-to-buffer proc-buf)
	    (message "No error found.")) 
	(setq n (seq-position (mapcar 'buffer-file-name (buffer-list)) e-file))
	(cond
	 (n (switch-to-buffer (seq-elt (buffer-list) n)))
	 ((file-exists-p e-file) (find-file e-file))
	 (t (setq e-beg nil)))
	(if (not e-beg)
	    (message "%s\n containing the build error has been deleted" e-file)
	  (goto-char (point-max))
	  (forward-line  (-  e-beg (line-number-at-pos))) ;
	  (scroll-up 1)))))))

(defun rnw2pdf-biblog ()
  "Given the Rnw document buffer, visit the associated bibliography log file (the .blg file), if any."
  (interactive)
  (if (not (buffer-file-name))
      (message "This buffer is not associated with a file")

    (let* ((rnw-path (buffer-file-name))
	   (rnw-dir (file-name-directory rnw-path))
	   (aux-dir (file-name-as-directory (expand-file-name rnw2pdf-aux rnw-dir)))
	   (bib-log (expand-file-name
		     (rnw2pdf/change-ext (file-name-nondirectory rnw-path) ".blg")
		     aux-dir)))

      (cond     
       ((not (rnw2pdf/get-pbuf rnw-path))
	(message "I can't find build info for the document\n%s\nDid you delete the its process buffer."
		 rnw-path))
       
       ((not (file-exists-p bib-log))
	(message "There is no available  bibliography log file\n%s\n." bib-log))
     
       (t (find-file bib-log))))))


(defun rnw2pdf-build-log ()
  "Given the Rnw document buffer, visit the build log buffer."
  (interactive)
  (let* ((rnw-path (buffer-file-name))
	 proc-buf)

    (cond     
     ((not rnw-path) (message "This buffer is not associated with a file"))
     ((not (setq proc-buf (rnw2pdf/get-pbuf rnw-path)))
      (message "There is no build buffer available for \n%s"
	      rnw-path))
     (t  (switch-to-buffer proc-buf)))))



;;; Process Helpers
;;; ===============

(defun rnw2pdf/get-pbuf  (rnw-path)
  "Get the process buffer associated with RNW-PATH."
  (cdr (assoc rnw-path rnw2pdf/rnw-alist)))

(defun rnw2pdf/get-pbuf-name  (rnw-path)
  "Get the process buffer name associated with RNW-PATH."
  (buffer-name (rnw2pdf/get-pbuf rnw-path)))


(defun rnw2pdf/make-short-name  (rnw-path)
  "Given the Rnw document path RNW-PATH, generate the name of the process buffer to receive the output of R & LaTeX. The name is based on the last three components of RNW-PATH, if there is no conflict, or on the absolute path. Error exit if the RNW-PATH has no  \".Rnw\" extension (case insensitive).

Since the process buffer is not associated to a file (unless the user saves it), to detect conflicts the buffer local variable `associated-rnw-path' is set to the path of the Rnw document to process. A buffer with the name generated here migh already exist when we re-build the same document. There is a name conflict if the local value of `associated-rnw-path' is not RNW-PATH."
  
  (let* ((path (abbreviate-file-name (file-name-sans-extension (expand-file-name rnw-path))))
	 (ext (file-name-extension (expand-file-name rnw-path)))
	 (comps (split-string path "/"))
	 short-name long-name short-buf)

    ;; Check extension 
    (unless (string= "RNW" (upcase ext))
      (rnw2pdf/ret
       (format
	"ERROR: Please, use the \"Rnw\" extension (case insensitive) for the document. Current name is instead \n%s:"
	(file-name-nondirectory rnw-path))))

    ;; Extract 3 path components
    (setq 
     comps (if (> (length comps) 3) (last comps 3))
     comps (mapconcat 'identity comps "/")
     short-name (concat "*" comps " rnw2pdf output*")
     long-name  (concat "*" path " rnw2pdf*"))

    (setq short-buf (get-buffer short-name))
    (cond
     ;; short-name does not exist so can be used
     ((not short-buf) short-name) 
     ;; short-buf is not of the type expected, so  use long-name
     ((not (local-variable-p 'associated-rnw-path short-buf)) long-name)
     ;; we are re-building: short-buf exist and is associated to our document
     ((string= (buffer-local-value 'associated-rnw-path short-buf) rnw-path) short-name)
     (t long-name))))

(defun rnw2pdf/set-r2p-path (rnw-path-sans)
  "File like \"foo.r2p\" containing knit code for \"foo.Rnw\""
  (let* ((rnw-dir (file-name-directory rnw-path-sans))
	 (r2p (concat rnw-path-sans ".r2p")) 
	 aux-dir)
    
    (if (not rnw2pdf-aux)
	r2p
      (setq aux-dir (file-name-as-directory (expand-file-name rnw2pdf-aux rnw-dir)))
      r2p (expand-file-name (file-name-nondirectory r2p) aux-dir))))

	 

;;; Misc Helpers
;;; ============

;(defmacro rnw2pdf/ret (mess)
;        `(throw 'rnw2pdf/main ,mess))

(defun rnw2pdf/ret (mess) ; replace defmacro above, not tested for all cases 
  (throw 'rnw2pdf/main mess))


(defun rnw2pdf/r-path ()
  "Obtain R executable path, using `rnw2pdf-r-path', if non-nil, or search path."
  (if rnw2pdf-r-path 
      (shell-quote-argument rnw2pdf-r-path)
    (executable-find "Rscript")))

(defun rnw2pdf/change-ext (file ext)
  "Change extension of FILE to EXT."
  (concat (file-name-sans-extension file ) ext))

 
(defun rnw2pdf/remove-nth-element (nth list)
  "Destructively remove NTH element from LIST.
https://emacs.stackexchange.com/a/29791/3975"
  (if (zerop nth) (cdr list)
    (let ((last (nthcdr (1- nth) list)))
      (setcdr last (cddr last))
      list)))

(defun rnw2pdf/remove-killed-buffers ()
  "Remove killed buffers from `rnw2pdf/rnw-alist'"
  (setq rnw2pdf/rnw-alist
	(seq-filter #'(lambda (path-buf)
		      (buffer-live-p (cdr path-buf))) rnw2pdf/rnw-alist)))

(defun rnw2pdf-find-r-win ()
  "Find the path of \"Rscript\" executable for Windows using the pattern
\"%ProgramFiles%/R/R-*/bin/Rscript.exe\".
If more versions are found, the last path in alphabetical order (perhaps the lastest version) is used.
If the executable is not found or the platform symbol is not 'windows-nt, nil is returned."
  (interactive)
  (when (eq system-type 'windows-nt)
    (let* ((win-prg (getenv "ProgramFiles")))
      (car (last (file-expand-wildcards (concat win-prg "/R/R-*/bin/Rscript.exe")))))))

(provide 'rnw2pdf)
