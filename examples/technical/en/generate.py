#!/usr/bin/env python3
"""Generate an English sample Huawei Cloud technical report (DOCX)."""

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 '..', '..', '..', 'templates', 'technical'))
from huawei_technical import *

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

def main():
    replacements = {
        'TITLE': '[Analysis Report] The Enterprise Project List Is Not Displayed '
                 'on the ECS Creation Page in 8.5.1 at the Brazil Site',
        'RELEASE_DATE': '2025-08-13',
        'PROBLEM_DESCRIPTION':
            'At the Brazil site of HCS 8.5.1, the default enterprise project '
            'is not displayed on the ECS creation page. This prevents users '
            'from selecting the correct enterprise project when provisioning '
            'new ECS instances.',
        'ROOT_CAUSE_ANALYSIS':
            '1. Analyzed the permissions of the user who cannot view the '
            'default enterprise project\n'
            '2. Verified the auth_action field behavior in version 8.5.1\n'
            '3. Confirmed the Server Administrator role lacks fine-grained '
            'action permissions',
        'ROOT_CAUSE':
            'In version 8.5.1, the fine-grained permission scenario was '
            'optimized. When an ECS is provisioned, only enterprise projects '
            'with the appropriate permissions are listed. The Server '
            'Administrator role does not include ECS FullAccess.',
        'TRIGGER_CONDITION':
            'Occurs when a user with only the Server Administrator role '
            'attempts to create an ECS instance in HCS 8.5.1.',
        'IMPACT':
            'To grant ECS FullAccess to a user, you need to modify the user '
            'group permission. This permission is the ECS administrator '
            'permission and is included in the Server Administrator permission.',
        'BACKUP_DATA': 'N/A — no data modification required.',
        'WORKAROUND':
            '1. Log in to the tenant plane and find the user group associated '
            'with the affected user\n'
            '2. Add the ECS FullAccess permission to the user group\n'
            '3. Verify the permission is applied correctly',
        'VERIFICATION':
            'Log in to the tenant page again, go to the ECS page, create an '
            'ECS, and verify the enterprise project list is now displayed.',
        'ROLLBACK': 'Remove the ECS FullAccess permission from the user group.',
        'CLEANUP': 'No cleanup required.',
        'VERSION': 'HCS 8.5.1',
        'SCENARIO': 'Standard Scenario',
    }

    doc = create_technical_report(replacements)
    path = save_report(doc, os.path.join(OUT_DIR, "sample-report.docx"))
    print(f"Saved: {path}")

if __name__ == "__main__":
    main()
