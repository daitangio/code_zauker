module CodeZauker
  DEFAULT_EXCLUDED_EXTENSION=[
                              # Documents
                              ".pdf",
                              ".xps",
                              ".zip",
                              ".ppt",".xls",".rtf",".vsd",  
                              ".dll",".exe",".out",".elf",".lib",".so",
                              # Redis db
                              ".rdb",
                              # Ruby and java stuff-like
                              ".gem",
                              ".jar",".class",
                              ".tar",
                              ".gz",
                              ".dropbox",
                              ".svn-base",".pdb",".cache",
                              # MS Office zip-like files...
                              ".pptx",".docx",".xlsx",
                              # Music exclusion
                              ".mp3",".mp4",".wav",
                              # Image exclusion
                              ".png",".gif",
                              # Temp stuff
                              ".tmp","~",
                              # Oracle exports...
                              ".exp"
                              ]
end
