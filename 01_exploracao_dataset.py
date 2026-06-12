"""
=============================================================
TCC - Sistema de Detecção de Dependência Digital
Passo 1: Exploração Inicial do Dataset LSApp
=============================================================
Dataset: LSApp (Large dataset of Sequential mobile App usage)
Fonte: https://github.com/aliannejadi/LSApp
Publicação: ACM TOIS 2021
=============================================================
"""

import pandas as pd
import numpy as np

# ============================================================
# 1. CARREGAR O DATASET
# ============================================================
print("=" * 60)
print("CARREGANDO DATASET LSApp...")
print("=" * 60)

df = pd.read_csv('lsapp.tsv', sep='\t')

print(f"\n✅ Dataset carregado com sucesso!")
print(f"   Total de registros: {len(df):,}")
print(f"   Colunas: {list(df.columns)}")

# ============================================================
# 2. VISÃO GERAL DOS DADOS
# ============================================================
print("\n" + "=" * 60)
print("VISÃO GERAL DOS DADOS")
print("=" * 60)

print(f"\n📊 Primeiras linhas:")
print(df.head(10).to_string())

print(f"\n📊 Tipos de dados:")
print(df.dtypes)

print(f"\n📊 Valores nulos:")
print(df.isnull().sum())

# ============================================================
# 3. ESTATÍSTICAS BÁSICAS
# ============================================================
print("\n" + "=" * 60)
print("ESTATÍSTICAS BÁSICAS")
print("=" * 60)

print(f"\n👥 Número de usuários únicos: {df['user_id'].nunique()}")
print(f"📱 Número de sessões únicas: {df['session_id'].nunique()}")
print(f"📲 Número de apps únicos: {df['app_name'].nunique()}")

print(f"\n🔄 Tipos de eventos:")
print(df['event_type'].value_counts())

# ============================================================
# 4. ANÁLISE TEMPORAL
# ============================================================
print("\n" + "=" * 60)
print("ANÁLISE TEMPORAL")
print("=" * 60)

df['timestamp'] = pd.to_datetime(df['timestamp'])

print(f"\n📅 Período dos dados:")
print(f"   Início: {df['timestamp'].min()}")
print(f"   Fim: {df['timestamp'].max()}")
print(f"   Duração total: {(df['timestamp'].max() - df['timestamp'].min()).days} dias")

# Extrair hora do dia
df['hour'] = df['timestamp'].dt.hour
print(f"\n🕐 Distribuição por hora do dia (top 5 horários mais ativos):")
hour_counts = df['hour'].value_counts().sort_index()
top_hours = hour_counts.sort_values(ascending=False).head(5)
for hour, count in top_hours.items():
    print(f"   {int(hour):02d}:00 - {count:,} eventos")

# ============================================================
# 5. ANÁLISE POR USUÁRIO
# ============================================================
print("\n" + "=" * 60)
print("ANÁLISE POR USUÁRIO")
print("=" * 60)

user_stats = df.groupby('user_id').agg(
    total_eventos=('timestamp', 'count'),
    total_sessoes=('session_id', 'nunique'),
    total_apps=('app_name', 'nunique'),
    primeiro_evento=('timestamp', 'min'),
    ultimo_evento=('timestamp', 'max')
).reset_index()

user_stats['dias_monitorados'] = (user_stats['ultimo_evento'] - user_stats['primeiro_evento']).dt.days + 1
user_stats['eventos_por_dia'] = user_stats['total_eventos'] / user_stats['dias_monitorados']
user_stats['sessoes_por_dia'] = user_stats['total_sessoes'] / user_stats['dias_monitorados']

print(f"\n📈 Estatísticas por usuário:")
print(f"   Eventos por usuário (média): {user_stats['total_eventos'].mean():.0f}")
print(f"   Sessões por usuário (média): {user_stats['total_sessoes'].mean():.0f}")
print(f"   Apps únicos por usuário (média): {user_stats['total_apps'].mean():.1f}")
print(f"   Dias monitorados (média): {user_stats['dias_monitorados'].mean():.1f}")
print(f"   Eventos por dia (média): {user_stats['eventos_por_dia'].mean():.1f}")
print(f"   Sessões por dia (média): {user_stats['sessoes_por_dia'].mean():.1f}")

# ============================================================
# 6. TOP APPS MAIS USADOS
# ============================================================
print("\n" + "=" * 60)
print("TOP 15 APPS MAIS USADOS")
print("=" * 60)

top_apps = df['app_name'].value_counts().head(15)
for i, (app, count) in enumerate(top_apps.items(), 1):
    print(f"   {i:2d}. {app}: {count:,} eventos")

# ============================================================
# 7. RESUMO FINAL
# ============================================================
print("\n" + "=" * 60)
print("RESUMO - VIABILIDADE PARA O PROJETO")
print("=" * 60)

print("""
✅ O dataset é VIÁVEL para o projeto porque contém:
   
   1. TIMESTAMPS REAIS → Podemos calcular:
      - Uso noturno (sessões entre 00h-05h)
      - Intervalos entre sessões
      - Padrões de escalonamento ao longo dos dias
   
   2. SESSÕES IDENTIFICADAS → Podemos calcular:
      - Duração estimada de cada sessão
      - Frequência de sessões por dia
      - Padrões de uso compulsivo (muitas sessões curtas)
   
   3. NOMES DE APPS → Podemos calcular:
      - Índice de compulsividade (reabertura do mesmo app)
      - Entropia de uso (variedade vs foco obsessivo)
      - Categorização de apps (social, games, produtividade)
   
   4. MÚLTIPLOS USUÁRIOS (292) → Podemos:
      - Treinar modelo com diversidade de comportamentos
      - Criar labels de risco baseados em padrões extremos
      - Validar com cross-validation

⚠️  PRÓXIMO PASSO: Engenharia de Features (Script 02)
""")
