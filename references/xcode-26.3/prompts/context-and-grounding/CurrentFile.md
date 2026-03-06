---
title: CurrentFile
xcode_version: 26.3
category: context-and-grounding
resource_kind: prompt-template
source_app: /Volumes/eyedisk/Applications/Xcode.app
source_file: /Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/CurrentFile.idechatprompttemplate
original_filename: CurrentFile.idechatprompttemplate
---

# CurrentFile

Source app: `/Volumes/eyedisk/Applications/Xcode.app`
Source file: `/Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/CurrentFile.idechatprompttemplate`
Category: `context-and-grounding`
Kind: `prompt-template`

## Extracted Content

The user is currently inside this file: {{ currentFile.fileName }}
The contents are below:
```{{ currentFile.language }}:{{ currentFile.fileName }}
{{ currentFile.code }}
```
