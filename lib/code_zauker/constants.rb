module CodeZauker
  # Under Amazon AWS, a lot of timeout can happen.
  # We put a higer retry here
  MAX_PUSH_TRIGRAM_RETRIES=15
  # Stats 
  # It is difficult to decide what is the best trigram push size.
  # a larger one ensure a best in memory processing but can lead to longer transactions
  # 6000 Ehuristic value used for historical reasons
  TRIGRAM_DEFAULT_PUSH_SIZE=6000
  DEFAULT_EXCLUDED_EXTENSION=[
                              # Documents                             
                              ".xps",
                              ".zip",".7z","rar",
                              # MS Office zip-like files...
                              ".pptx",".docx",".xlsx",
                              # MS Visual Studio big bad files"
                              ".scc",".datasource",".pdb","vspscc",".settings",
                              #"Telerik.Web.UI.xml",
                              ".Web.UI.xml",
                              # Auto-generated stuff...is suggested to be avoided
                              ".designer.cs",
                              # Avoid slurping text document too...
                              ".doc",
                              ".ppt",".xls",".rtf",".vsd", ".odf",
                              # Binary bad stuff
                              ".dll",".exe",".out",".elf",".lib",".so",
                              # Redis db
                              ".rdb",
                              # Ruby and java stuff-like
                              ".gem",
                              ".jar",".class",".ear",".war",
                              ".mar",
                              ".tar",
                              ".gz",".Z",
                              ".dropbox",
                              ".svn-base",".cache", 
                              #IDE STUFF
                              ".wlwLock",
                              # Music exclusion
                              ".mp3",".mp4",".wav",
                              # Image exclusion
                              ".png",".gif",".jpg",".bmp",
                              # Temp stuff and logs
                              ".tmp","~",".log",".bar",
                              # Oracle exports...
                              ".exp"
                              ]
end
