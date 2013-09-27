
;; The following defines the site for producing the html documentation of DynSite
;; Running the expression below installs the site for publishing the site found
;; in ../dynsite-org/ to the folder ../dynsite-html/
;; Both of the above folders are included in the present release. 
;; The paths given here are absolute. You need to change them to match the location
;; of the dynsite folder in your own system. 
;; Then run org-choose-site, choose cynsite. 
;; Then run org-publish, and choose dynsite-all as project.

(org-install-site
     '("dynsite"
       "~/Documents/Dev/Emacs/dynsite/dynsite-org"
 ;; path of the folder where the html files will be published:
       "~/Documents/Dev/Emacs/dynsite/dynsite-html"
 ;; this string will be used as address to upload files to web with rsync:
        "earlabor@earlab.org:public_html/larigot-tests/dynsite"))

