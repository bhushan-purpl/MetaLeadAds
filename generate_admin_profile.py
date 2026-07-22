import os

profile_xml = '<?xml version="1.0" encoding="UTF-8"?>\n<Profile xmlns="http://soap.sforce.com/2006/04/metadata">\n'
base_path = 'meta-lead-ads-package/main/default/objects'

for obj in os.listdir(base_path):
    if obj.endswith('__c'):
        fields_path = os.path.join(base_path, obj, 'fields')
        if os.path.exists(fields_path):
            for field in os.listdir(fields_path):
                if field.endswith('.field-meta.xml'):
                    field_name = field.replace('.field-meta.xml', '')
                    profile_xml += f'    <fieldPermissions>\n        <editable>true</editable>\n        <field>{obj}.{field_name}</field>\n        <readable>true</readable>\n    </fieldPermissions>\n'

profile_xml += '</Profile>'

os.makedirs('meta-lead-ads-package/main/default/profiles', exist_ok=True)
with open('meta-lead-ads-package/main/default/profiles/Admin.profile-meta.xml', 'w') as f:
    f.write(profile_xml)
