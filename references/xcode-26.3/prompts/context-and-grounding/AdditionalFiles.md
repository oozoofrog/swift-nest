---
title: AdditionalFiles
xcode_version: 26.3
category: context-and-grounding
resource_kind: prompt-template
source_app: /Volumes/eyedisk/Applications/Xcode.app
source_file: /Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalFiles.idechatprompttemplate
original_filename: AdditionalFiles.idechatprompttemplate
---

# AdditionalFiles

Source app: `/Volumes/eyedisk/Applications/Xcode.app`
Source file: `/Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalFiles.idechatprompttemplate`
Category: `context-and-grounding`
Kind: `prompt-template`

## Extracted Content

The user has also provided the following Swift files that may be useful to answer their question:
{% for additionalFile in additionalFiles %}
```{{ additionalFile.language }}:{{ additionalFile.fileName }}
{{ additionalFile.code }}
```
{% endfor %}
