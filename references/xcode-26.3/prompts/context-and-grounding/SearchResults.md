---
title: SearchResults
xcode_version: 26.3
category: context-and-grounding
resource_kind: prompt-template
source_app: /Volumes/eyedisk/Applications/Xcode.app
source_file: /Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/SearchResults.idechatprompttemplate
original_filename: SearchResults.idechatprompttemplate
---

# SearchResults

Source app: `/Volumes/eyedisk/Applications/Xcode.app`
Source file: `/Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/SearchResults.idechatprompttemplate`
Category: `context-and-grounding`
Kind: `prompt-template`

## Extracted Content

Your search results are provided below:
{% for fileResult in fileResults %}
```{{ fileResult.language }}:{{ fileResult.fileName }}
{{ fileResult.code }}
```
{% endfor %}

{{ message }}
