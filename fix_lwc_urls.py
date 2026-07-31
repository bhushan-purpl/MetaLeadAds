import re
import glob

# Revert purplsync.com back to purplstack.com in LWC HTML files
lwc_files = glob.glob('meta-lead-ads-package/main/default/lwc/**/*.html', recursive=True)

for path in lwc_files:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    new_content = content.replace('purplsync.com', 'purplstack.com')
    if new_content != content:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Reverted URLs in {path}")
