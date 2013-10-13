;;; config.el --- Example config file for a site.

;;; Commentary: 

;;; Edit this file to install your site, then run it with (load-file <filename>).

;; The file does the following: 
;; Load dynsite package.
;; Install an example website 'dynsite' included with the package.
;; Make 'dynsite' the current site.
;; Following this, the command 'org-publish will present a list of 
;; projects contained in the site for publishing. 

;; Load dynside package.
(require 'dynsite)

;; Install site.
;; Running following expression installs the site for publishing the site found
;; in ../dynsite-org/ to the folder ../dynsite-html/
;; Both of the above folders are included in the present release. 
;; The paths given here are absolute. You need to change them to match the location
;; of the dynsite folder in your own system. 
(org-install-site
     '("dynsite"
;;       "~/Documents/Dev/Emacs/dynsite/dynsite-org"
       "./dynsite-org"
;; path of the folder where the html files will be published:
       "./dynsite-html"
;; this string will be used as address to upload files to web with rsync:
;; It may be left empty. 
        "username@hostname.org:public_html/path-to/target-folder"))

;; Choose the site just installed above, making it current:
(org-set-site (car org-sites))
