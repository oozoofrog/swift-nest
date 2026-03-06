---
title: CodingToolTemplateDocument
xcode_version: 26.3
category: generation-tools
resource_kind: prompt-template
source_app: /Volumes/eyedisk/Applications/Xcode.app
source_file: /Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/CodingToolTemplateDocument.idechatprompttemplate
original_filename: CodingToolTemplateDocument.idechatprompttemplate
---

# CodingToolTemplateDocument

Source app: `/Volumes/eyedisk/Applications/Xcode.app`
Source file: `/Volumes/eyedisk/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/CodingToolTemplateDocument.idechatprompttemplate`
Category: `generation-tools`
Kind: `prompt-template`

## Extracted Content

I need you to generate documentation for the following code selection.

**File**: {{ FilePath }}
**Lines**: {{ StartLine }}-{{ EndLine }}

{% if SelectedCode %}**Selected Code**:
```
{{ SelectedCode }}
```
{% endif %}

Please use the XcodeRead tool to read the full file context if needed, then generate appropriate documentation comments for this code. Follow Swift documentation conventions:
- Use /// for single-line documentation comments
- Use /** ... */ for multi-line documentation comments
- Include parameter descriptions, return values, and throws information where applicable
- Add usage examples if helpful

**Important**: After creating the documentation, use the XcodeUpdate tool to replace the original code with the documented version in the file.
