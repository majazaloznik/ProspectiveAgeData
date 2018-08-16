# preliminaires
library(rfigshare)

# get info on all files in deposit
x <- fs_details(6974414)
# extract ids of the three files
file.ids <- sapply(x$files, function(x) x$id)

# remove existing files using these ids and replace with current versions. 
lapply(file.ids, function(x) fs_delete(6974414, x))

# upload new versions of files
fs_upload(6974414, "docs/codebook.pdf")
fs_upload(6974414, "docs/methods.pdf")
fs_upload(6974414, "data/04_human-readable/2017_prospective-ages.csv")

# publish new version. 
fs_make_public(6974414)
