;;; dynsite.el --- Configure and manage orgmode publishing projects. 

;;; Commentary:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Basic commands: ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Building the projects definitions to work with (the sites are made later based on these):
;; org-build-projects: Construct and store all project defs in org-publish-project-alist
;; Help on using this publish setup is found in file org-publish-help.org, in the same folder
;; as the present setup file

;; Overview: 
;; org-site-root contains the path to the root directory containing all  org-sites
;; org-site-html contains the path for publishing sites in html
;; org-publish-regexp is the expression for replacing the base path with the html publish path
;; org-config-file-data is the list of data for building the plist of each project
;; org-project-def-files finds all folders containing config.org files under org-site-root.
;; org-project-def-lists list of project paths together with containing superprojects paths. 
;; org-project-defs is an assoc list containing a project definition for each project path.

;; DONE: 
;; - modify plist generation to use org nodes only, no #+ single line headers
;; - single line properties should be indicated by propertyname: property in the node heading
;; - construct origin and target folder property for each project
;; - construct filetype property for each project (given in template?)
;; - add default heading and other properties in project plist def
;; - construct folder exclude property for each project
;; - add subfolder projects to exclude regexp for each project
;; - (DEBUG:) sort super/subfolders so that inheritance of properties is correct
;; - add mechanism to permit multiple projects with same folder names
;;   Suggestion: just concat the names of the superfolders for all projects, 
;;   in reverse order.  Examples:
;;   org (top level project) 
;;   subfolder1/org (subproject of top level project)
;;   subsubfolder1/subfolder1/org (subproject of subproject of top level project)
;;   This way the name of the project reflects its full identity!
;;   Add mechanism for inserting paths relative to the root of the project
;;   at any point in the html file, by marking the root of the project as {{.}}
;; - Add all website .org files of org directory to org-refile-targets
;;   for access of their org nodes via autocomplete. 
;;   This is coded in interactive function org-publish-add-all-files-to-refile-targets
;; - Create sitemap sitemap.org
;; - Utility function for editing all configs: org-publish-edit-all-configs
;; - construct rsync or git shell commands for uploading published projects
;;   Done: a single function for rsyncing the entire folder. 
;; - construct media copy projects and link them to each html export project
;;   use the three project mechanism described in: 
;;   http://orgmode.org/worg/org-tutorials/org-publish-html-tutorial.html#sec-3
;; - Create function for touching all files in org folder, to force re-export
;;   The interactive function is org-reset-all-project-files
;;   it uses: (shell-command "find /Users/iani/org/* -exec touch {} \\;")
;; - Create global project "all" to publish all projects.
;; - defvar org-site-url to customize rsync upload method 
;; - defvar org-sites assoc list to store different site configurations
;;   These consist of : (name org-site-root org-site-html org-site-url)
;; - defun org-choose-site to switch 

;;; Code:

;; following variables are needed for publishing as of orgmode version 7.8.03:
(setq org-sitemap-file-entry-format "%t")
(setq org-sitemap-date-format "%d")

(global-set-key [remap eval-last-sexp] 'pp-eval-last-sexp)

(load-library "find-lisp")
(defcustom org-site-root "~/org"
  "the directory of the root org file folder for all org to html projects.
  You can customize this variable for your emacs application by executing:
  Meta-x customize-variable
  And then entering org-site-root as the name of the variable to customize"
)

(defcustom org-site-html nil
  "the directory of the root folder where the sites are exported in html.
  You can customize this variable for your emacs application by executing:
  Meta-x customize-variable
  And then entering org-site-html as the name of the variable to customize"
)

(defvar org-publish-regexp nil
  "regexp for replacing org base path component with publish base path component")

(defvar org-relative-path nil
  "path relative to root substituted for expression {{.}} in html files before publishing")

(defvar org-config-file-data nil
  "data needed to build the final org publish project alist")

;; (defvar org-upload-automatically-p nil
;;  "if t, then rsync will be called after publishing")

(defcustom org-site-url "earlabor@earlab.org:~/public_html/org/"
  "string used to create and execute the rsync command for uploading the currently chosen site")

(defvar org-sites (list (list "default" org-site-root org-site-html org-site-url))
  "Assoc list of site project configurations. Structure:
   ((name org-site-root org-site-html org-site-url) (name org-site-root ...) ...)")

(defvar org-current-site (car org-sites)
  "alist of the currently chosen site for DynSite export")

;; (defvar org-default-site (car org-sites)
;;  "alist of the default site")

;; Initialise org-sites assoc list:
;;(unless org-sites 
;;  (setq org-sites (list (list "default" org-site-root org-site-html org-site-url))))

;;;###autoload

;; TODO: If a site with the same name already exists, then remove it. 
(defun org-install-site (sitespecs)
  "add a list defining a site's folders and url to the list of known sites, and make it active"
;;  (require 'org-publish)
  (require 'cl)
  (setq org-current-site sitespecs)
  (add-to-list 'org-sites org-current-site)
;; do not set site at this stage. This saves time when installing large sites
;;  (org-set-site org-current-site)
  )

(defun org-choose-site (site)
  "Choose site configuration, setting org-site-root, org-site-html, org-site-url"
  (interactive
   (let ((choice (assoc (org-icompleting-read
                         "Choose site: " org-sites nil t)
                        org-sites)))
     (if (not choice) (setq choice (car org-sites)))
     (org-set-site choice)
     (list (message (format "you chose: %s" (car choice))))
     ))
  )

(defun org-set-site (site)
  (setq org-current-site site)
  (let ((settings (cdr site)))
    (setq org-site-root (pop settings))
    (setq org-site-html (pop settings))
    (setq org-site-url (pop settings)))
  (org-build-projects))

;; (global-set-key (kbd "C-s-B") 'org-build-projects)

(defun org-build-projects ()
  "Build all org publishing projects based on config.org files inside org-site-root directory"
  (interactive)
  (org-build-config-file-data)
  (message "project defs created: %s" (mapcar 'car org-publish-project-alist)))

(global-set-key (kbd "C-s-B") 'org-build-projects)

(defun org-build-config-file-data ()
  "find all config.org files and scan their contents. Then
   build org-config-file-data"
  ;; (re-) initialize org-publish data first: 
  (setq org-publish-project-alist nil)
  (setq org-site-root (expand-file-name org-site-root))
  (setq org-publish-regexp (concat "^" org-site-root))
  (if (not org-site-html)
      (setq org-site-html (concat org-site-root "/html")))
  (setq org-site-html (expand-file-name org-site-html))
  ;; scan all config.org file data
  (setq org-config-file-data
	(mapcar
	 (lambda (path)
	   (let* ((org-folder (file-name-directory path))
		  (html-folder 
		   (replace-regexp-in-string org-publish-regexp org-site-html org-folder))
		  (proj-name
		   (directory-file-name 
		    (replace-regexp-in-string 
		     (file-name-directory org-publish-regexp) "" org-folder)))
		  (name
		   (let (n)
		     (dolist (p (reverse (split-string proj-name "/")))
		       (setq n (concat n p "/" )))
		     (directory-file-name n))))
	     (list
	      name
	      (list
	       :path path
	       :default-properties (org-default-publish-properties org-folder html-folder)
	       :custom-properties (org-custom-properties path)))))
	 (find-lisp-find-files org-site-root "config.org$")))
;; find subprojects and superprojects, merge their properties, create exclude regexps
  (let ((names (mapcar (lambda (d) (car d)) org-config-file-data)))
    (dolist (proj org-config-file-data)
      (let ((name (car proj)) superprojects 
	    subprojects project-def project-all-def project-static-def)
	  (dolist (sup names)
	    (if (string-match (concat sup "$") name)
		;; inherit self as superproject to copy your own data to self at end
		(setq superprojects (cons sup superprojects)))
	    (if (string-match (concat name "$") sup)
		(if (not (equal sup name)) ;; do not inherit self as subproject
			 (setq subprojects (cons sup subprojects)))))

;; here get default project plist, 
	  (setq project-def (copy-list (plist-get (cadr proj) :default-properties)))
;; Construct :folder-exclude regexp from subprojects
	  (setq 
	   project-def
	   (plist-put 
	    project-def :folder-exclude
	      (concat "~$" (eval (cons 'concat (mapcar 
		(lambda (p) 
		 (concat "\\|^" 
		   (file-name-directory 
		    (plist-get (cadr (assoc p org-config-file-data)) :path))))
		subprojects))))))
;; then merge custom plists of superprojects using dolist on superprojects
	  (dolist 
	      (ip
	       (mapcar (lambda (p) 
			 (plist-get (cadr (assoc p org-config-file-data)) :custom-properties))
		       superprojects))
	    (dolist (p ip)
	      (setq project-def (plist-put project-def
					   (intern (concat ":" (car p)))
					   (cdr p)))))
;; Now replace / with < in name to prevent error in timestamp cache file creation
	  (setq name (replace-regexp-in-string "/" "<" name))
;; add the completed project-def to org-modes project list: 
	  (add-to-list 'org-publish-project-alist (cons name project-def))
;; add group project for publishing org + static components of site
;; example: ("org" :components ("org-notes" "org-static"))
	  (add-to-list 'org-publish-project-alist 
		       (list (concat name "-all")
			     :components
			     (list name (concat name "-static"))))
;; add static project (non-html parts)
 	  (add-to-list 'org-publish-project-alist
		       (list (concat name "-static")
			     :base-directory  (plist-get project-def :base-directory)
			     :publishing-directory (plist-get project-def :publishing-directory)
			     :recursive t
			     :base-extension "css\\|html\\|js\\|ppt\\|doc\\|xls\\|dwg\\|zip\\|png\\|jpg\\|gif\\|pdf\\|mp3\\|ogg\\|swf"  ;;change 121114 by ari
			     ;; :base-extension "css\\|js\\|zip\\|png\\|jpg\\|gif\\|pdf\\|mp3\\|ogg\\|swf" 
			     :folder-exclude (plist-get project-def :folder-exclude)
			     :publishing-function 'org-publish-attachment
			     )))))
;; At the end, add a project for publishing all projects
    (add-to-list 'org-publish-project-alist
		 (list "all-all"
		       :components 
		       (mapcar (lambda (pn) (car pn)) org-publish-project-alist))))

(defun org-default-publish-properties (base-directory publishing-directory)
  "construct default property plist for publishing"
  (list 
     :base-directory base-directory
     :publishing-directory publishing-directory
     :base-extension "org" ;; publish all org files
     :exclude "config.org$" ;; except config.org
     :section-numbers nil ;; do not add section numbers
     :with-sub-superscript nil ;; do not translate _ and ^ as subscript and superscript
     :table-of-contents t ;; generate a table of contents
;; did not get the following lines for making an index to do anything useful yet
;; I need to look at: http://orgmode.org/Changes_old.html, section "Index generation"
;;     :auto-index t ;; Automatic index generation. Where does this happen? 
;; next line produces an error ([2012-03-25 Sun 20:59])
;;     :makeindex t ;; makeindex again, according to http://orgmode.org/manual/Generating-an-index.html#Generating-an-index
     :recursive t ;; descend into subdirectories
     :publishing-function 'org-html-publish-to-html ;; publish to html
     :headline-levels 2 ;; only include headlines down to 2 levels in the table of contents
     :auto-preamble nil ;; do not use automatic preamble
     :auto-sitemap t                ; Generate sitemap.org automagically...
     :sitemap-filename "sitemap.org"  ; ... call it sitemap.org (it's the default)...
     :sitemap-title "Sitemap"         ; ... with title 'Sitemap'.
     ;; This does not bring the shell window to front so not activated yet:
;;     :completion-function 'org-upload-site-with-rsync
     :author "Ioannis Zannos & Aris Bezas"
     :email  "zannos AT gmail DOT com & aribezas AT gmail DOT com"))

;; (setq org-upload-automatically-p t) ;; not activated yet. see org-default-publish-properties

(defun org-upload-site-with-rsync ()
  "rsync entire contents of ~/org/html folder to site
This interactive version is just a wrapper for the non-interactive function
org-upload-site-with-rsync-noninteractive 
which is also used by org-republish-and-upload-site"
  (interactive)
  (org-upload-site-with-rsync-noninteractive))
 
(defun org-upload-site-with-rsync-noninteractive ()
  "start a shell and enter the rsync command for uploading the current site
This is a non-interactive function called by other interactive functions.
It must be non-interactive, because otherwise the shell window will not appear if called 
this function is called by other interactive functions
"
  (shell)
  (switch-to-buffer "*shell*") ;; only works when called as top-level function
  (insert-string (concat
		  "rsync -avz -e ssh --exclude '*.html~' --exclude 'config.org' "
		  (concat org-site-html "/") ;; avoid copying the folder itself!
		  " "
		  org-site-url
		  ))
  (message "Type return to send the rsync command to the shell"))

(defun org-custom-properties (file)
  "parse project def data in file and put them in a project-definition alist"
  (message "working on %s ..." file)
  (save-excursion
    (let ((buffer (find-file-noselect file)) def)
      (set-buffer buffer)
      (setq buffer-read-only t)
      (setq def (get-proj-def-from-org-nodes))
      (kill-buffer buffer)
      def)))

(defun get-proj-def-from-org-nodes ()
  (org-map-entries 
   '(save-excursion 
      (let* ((heading 
	      (progn 
		(re-search-forward (concat "^\\(" outline-regexp "\\)\\([^\n]*$\\)") nil 'move)
		(match-string-no-properties 2)))
	     (body 
	      (buffer-substring-no-properties (point) (org-entry-end-position))))
      (construct-proj-property heading body)))))

(defun construct-proj-property (heading body)
  "construct cons pair from heading and body of org node parsed by get-proj-def-from-org-nodes
   headings of the format <propertyname>: <property> create property-value pair"
  (let ((property-p (string-match "^\\([^: ]*\\): \\(.*\\)" heading)))
    (if property-p
	(cons (match-string 1 heading) (car (read-from-string (match-string 2 heading))))
      (cons heading body))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Adding the ability to filter subproject folders here: 

;;;###autoload
(defun org-publish-filtering-subprojects (project &optional force)
  "Publish PROJECT."
  (interactive
   (list
    (assoc (org-icompleting-read
	    "Publish project: "
	    org-publish-project-alist nil t)
	   org-publish-project-alist)
    current-prefix-arg))
  (setq org-publish-initial-buffer (current-buffer))
  (save-window-excursion
    (let* ((org-publish-use-timestamps-flag
	    (if force nil org-publish-use-timestamps-flag)))
      (org-publish-projects-filtering-subprojects
       (if (stringp project)
	   ;; If this function is called in batch mode,
	   ;; project is still a string here.
	   (list (assoc project org-publish-project-alist))
	   (list project))))))

(global-set-key (kbd "s-B") 'org-publish-filtering-subprojects)

(defun org-publish-projects-filtering-subprojects (projects)
  "Publish all files belonging to the PROJECTS alist.
If :auto-sitemap is set, publish the sitemap too.
If :makeindex is set, also produce a file theindex.org.
This is a version modified by IZ to filter folders that contain their own projects.
This is done using property :folder-exclude"
  (mapc
   (lambda (project)
     ;; Each project uses it's own cache file:
     (org-publish-initialize-cache (car project))
     (let*
	 ((project-plist (cdr project))
	  (exclude-regexp (plist-get project-plist :exclude))
	  (folder-exclude-regexp (plist-get project-plist :folder-exclude))
	  (sitemap-p (plist-get project-plist :auto-sitemap))
	  (sitemap-filename (or (plist-get project-plist :sitemap-filename)
				"sitemap.org"))
	  (sitemap-function (or (plist-get project-plist :sitemap-function)
				'org-publish-org-sitemap))
	  (preparation-function (plist-get project-plist :preparation-function))
	  (completion-function (plist-get project-plist :completion-function))
	  (files (org-publish-get-base-files project exclude-regexp)) file)
       (when preparation-function (run-hooks 'preparation-function))
       (if sitemap-p (funcall sitemap-function project sitemap-filename))
       (while (setq file (pop files))
;; Original, without subprojects filtering, without relative paths conversion:
;;	 (org-publish-file file project t))
;; IZ: Insert :exclude-regexp filter!
;; Above was before insertion. Below is after IZ insertion: 
;;       replace {{.}} with relative path (for menu links, css etc):
;; Note: This method is obsolete as of org-mode v. 8.0. 
;; Therefore replaced by org-html-provide-relative-path below.
	 (setq org-publish-after-export-hook 
	       (lambda () 
		 (replace-string "{{.}}" 
				 (org-make-relpath-string org-site-root file))))
;;       skip files that belong to subprojects: 
	 (if folder-exclude-regexp
	     (if (not (string-match folder-exclude-regexp file))
		 (org-publish-file file project t))
	   (org-publish-file file project t)))
       (when (plist-get project-plist :makeindex)
	 (org-publish-index-generate-theindex.inc
	  (plist-get project-plist :base-directory))
	 (org-publish-file (expand-file-name
			    "theindex.org"
			    (plist-get project-plist :base-directory))
			   project t))
       (when completion-function (run-hooks 'completion-function))
     (org-publish-write-cache-file)))
   (org-publish-expand-projects projects)))

;;; Provide relative path in org-mode 8.0 using filter mechanism
(defun org-html-provide-relative-path (string backend info)
  "Provide relative path for link."
  (when (org-export-derived-backend-p backend 'html)
    (replace-regexp-in-string 
     "{{.}}" 
     (org-make-relpath-string 
      org-site-root
      (plist-get info ':input-file))
     string)))

(add-to-list 'org-export-filter-final-output-functions
             'org-html-provide-relative-path)

(defun org-make-relpath-string (base-path file-path)
  "create a relative path for reaching base-path from file-path ('./../..' etc)"
  (let (
	(path ".")
	(depth (- 
		(length (split-string (file-name-directory file-path) "/"))
		(length (split-string base-path "/")))))
    (dotimes (number
	      (- depth 1)
	      path)
      (setq path (concat path "/..")))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; important util functions

(defun org-publish-edit-all-configs ()
  "edit all config.org files in the org website directory org-site-root"
  (interactive)
 (dolist (file (find-lisp-find-files org-site-root "config\\.org$"))
   (find-file file)))

(defun org-publish-add-all-files-to-refile-targets ()
  "Add all files in org-site-root to refile-targets for easy access with autocomplete."
  (interactive)
  (dolist (file (find-lisp-find-files org-site-root "\\.org$"))
    (if (not (equal "config.org" (file-name-nondirectory file)))
	(setq org-refile-targets 
	      (add-to-list 'org-refile-targets
			   (cons file '(:maxlevel . 2))))))
  (message "all site files have been added to refile targets"))

(defun org-publish-agenda-add-all-files ()
  "add all files in org-site-root to the agenda file list"
  (interactive)
  (dolist (file (find-lisp-find-files org-site-root "\\.org$"))
    (if (not (equal "config.org" (file-name-nondirectory file)))
	(setq org-agenda-files (cons file org-agenda-files)))) 
  (message "all site files have been added to the agenda"))


(global-set-key (kbd "s-R") 'org-publish-add-all-files-to-refile-targets)

(defun org-reset-all-project-files ()
  "touch all files in root folder so that they will be republished by org-publish"
  (interactive)
  (shell-command (concat "find " org-site-root "* -exec touch {} \\;")))

(defun org-dired-site ()
  "Dired org root folder of currently site"
  (interactive)
  (dired (cadr org-current-site)))

(defun org-interactive-dired-site (site)
  "Choose a site from the list of currently known sites and dired org root folder of site"
  (interactive
   (list
    (assoc (org-icompleting-read
	    "Choose site to dired: " org-sites nil t)
	    org-sites)))
  (message (format "you chose: %s" (cadr site)))
  (dired (cadr site)))

;; Republish all files of the current site and upload them
(defun org-republish-and-upload-site ()
  "re-construct site definition, re-export all files, upload"
  (interactive)
;;  (if (not org-current-site) 
;;      (org-set-site org-default-site)
;;      (org-build-projects))
;;  (org-reset-all-project-files)
  (org-build-projects)
  (org-publish-filtering-subprojects (assoc "all-all" org-publish-project-alist) t)
  (org-upload-site-with-rsync-noninteractive))

(global-set-key (kbd "C-M-s-P") 'org-republish-and-upload-site)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Example of recursive function
;; Get all keys of a plist
;; It is from: http://www.emacswiki.org/emacs/mon-plist-utils.el
;; Not used here. 
(defun plist-keys (in-plist)
  "Return a list of keys in IN-PLIST"
  (if (null in-plist)
      in-plist
    (cons (car in-plist) (plist-keys (cddr in-plist)))))

(provide 'dynsite)

;;; dynsite.el ends here
