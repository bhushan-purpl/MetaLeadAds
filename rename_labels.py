import os
import glob
import re

files_to_update = glob.glob('meta-lead-ads-package/main/default/**/*.xml', recursive=True)

for path in files_to_update:
    if os.path.isfile(path):
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Replace Purplstack with PurplSync only inside label tags (label, masterLabel)
        # Regex: match <label>...</label> and <masterLabel>...</masterLabel>
        
        def replace_label(match):
            inner = match.group(2).replace('Purplstack', 'PurplSync')
            return f"<{match.group(1)}>{inner}</{match.group(1)}>"
        
        new_content = re.sub(r'<(label|masterLabel)>(.*?)</\1>', replace_label, content, flags=re.DOTALL)
        
        if new_content != content:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Updated labels in {path}")
