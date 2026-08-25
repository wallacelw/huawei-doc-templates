#!/usr/bin/env python3
"""Gerar um relatório técnico de exemplo em português (DOCX)."""

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 '..', '..', '..', 'templates', 'technical'))
from huawei_technical import *

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

def main():
    replacements = {
        'TITLE': '[Relatório de Análise] A lista de projetos empresariais não é '
                 'exibida na página de criação do ECS na 8.5.1 no site do Brasil',
        'RELEASE_DATE': '2025-08-13',
        'PROBLEM_DESCRIPTION':
            'No site do Brasil do HCS 8.5.1, o projeto empresarial padrão '
            'não é exibido na página de criação do ECS. Isso impede que os '
            'usuários selecionem o projeto empresarial correto ao provisionar '
            'novas instâncias ECS.',
        'ROOT_CAUSE_ANALYSIS':
            '1. Analisadas as permissões do usuário que não visualiza o '
            'projeto empresarial padrão\n'
            '2. Verificado o comportamento do campo auth_action na versão 8.5.1\n'
            '3. Confirmado que a função Server Administrator não possui '
            'permissões de ação refinadas',
        'ROOT_CAUSE':
            'Na versão 8.5.1, o cenário de permissão refinada foi otimizado. '
            'Quando um ECS é provisionado, apenas os projetos empresariais com '
            'as permissões apropriadas são listados. A função Server '
            'Administrator não inclui ECS FullAccess.',
        'TRIGGER_CONDITION':
            'Ocorre quando um usuário com apenas a função Server Administrator '
            'tenta criar uma instância ECS no HCS 8.5.1.',
        'IMPACT':
            'Para conceder ECS FullAccess a um usuário, é necessário modificar '
            'a permissão do grupo de usuários. Esta permissão é a permissão de '
            'administrador do ECS e está incluída na permissão do Server '
            'Administrator.',
        'BACKUP_DATA': 'N/A — nenhuma modificação de dados necessária.',
        'WORKAROUND':
            '1. Faça login no plano de locatário e encontre o grupo de '
            'usuários associado ao usuário afetado\n'
            '2. Adicione a permissão ECS FullAccess ao grupo de usuários\n'
            '3. Verifique se a permissão foi aplicada corretamente',
        'VERIFICATION':
            'Faça login na página de locatário novamente, vá para a página do '
            'ECS, crie um ECS e verifique se a lista de projetos empresariais '
            'agora é exibida.',
        'ROLLBACK':
            'Remova a permissão ECS FullAccess do grupo de usuários.',
        'CLEANUP': 'Nenhuma limpeza necessária.',
        'VERSION': 'HCS 8.5.1',
        'SCENARIO': 'Cenário Padrão',
    }

    doc = create_technical_report(replacements)
    path = save_report(doc, os.path.join(OUT_DIR, "sample-report.docx"))
    print(f"Saved: {path}")

if __name__ == "__main__":
    main()
