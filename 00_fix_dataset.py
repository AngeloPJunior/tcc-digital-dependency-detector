"""
Fix: Remove a primeira linha (metadados tar) e adiciona header correto
Rode apenas UMA VEZ antes do script de exploração
"""

print("Corrigindo o arquivo lsapp.tsv...")

with open('lsapp.tsv', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Verifica se a primeira linha é o header correto ou lixo
if not lines[0].startswith('user_id'):
    # Remove a primeira linha (lixo do tar)
    lines = lines[1:]
    # Adiciona o header correto
    lines.insert(0, 'user_id\tsession_id\ttimestamp\tapp_name\tevent_type\n')
    
    with open('lsapp.tsv', 'w', encoding='utf-8') as f:
        f.writelines(lines)
    
    print("✅ Arquivo corrigido! Header adicionado.")
else:
    print("✅ Arquivo já está correto, nada a fazer.")
