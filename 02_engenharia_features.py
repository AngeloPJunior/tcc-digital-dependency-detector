"""
=============================================================
TCC - Sistema de Detecção de Dependência Digital
Passo 2: Engenharia de Features Comportamentais
=============================================================
Transforma dados brutos de uso de apps em variáveis
comportamentais que alimentam o modelo de ML.

Features extraídas por usuário (agregação diária):
  1. total_sessions       - Total de sessões no dia
  2. total_events         - Total de eventos no dia
  3. unique_apps          - Quantidade de apps distintos usados
  4. night_usage_ratio    - Proporção de uso noturno (00h-05h)
  5. avg_session_duration - Duração média das sessões (segundos)
  6. short_session_ratio  - Proporção de sessões muito curtas (<10s)
  7. top_app_ratio        - Concentração no app mais usado (%)
  8. app_entropy          - Entropia de Shannon (variedade de uso)
  9. reopening_index      - Índice de reabertura (mesmo app consecutivo)
  10. avg_inter_session   - Intervalo médio entre sessões (minutos)
=============================================================
"""

import pandas as pd
import numpy as np
from scipy.stats import entropy
import warnings
warnings.filterwarnings('ignore')

# ============================================================
# 1. CARREGAR E PREPARAR DADOS
# ============================================================
print("=" * 60)
print("PASSO 2: ENGENHARIA DE FEATURES COMPORTAMENTAIS")
print("=" * 60)

print("\n📂 Carregando dataset...")
df = pd.read_csv('lsapp.tsv', sep='\t')
df['timestamp'] = pd.to_datetime(df['timestamp'])
# Remover linhas com valores nulos (apenas 1 linha)
df = df.dropna()

df['user_id'] = df['user_id'].astype(int)
df['session_id'] = df['session_id'].astype(int)

# Extrair componentes temporais
df['date'] = df['timestamp'].dt.date
df['hour'] = df['timestamp'].dt.hour
df['day_of_week'] = df['timestamp'].dt.dayofweek  # 0=Monday, 6=Sunday

print(f"   ✅ {len(df):,} registros carregados")
print(f"   ✅ {df['user_id'].nunique()} usuários")

# ============================================================
# 2. CALCULAR FEATURES POR USUÁRIO POR DIA
# ============================================================
print("\n🔧 Calculando features comportamentais por usuário/dia...")
print("   (Isso pode levar alguns minutos...)\n")

def calculate_daily_features(group):
    """
    Calcula features comportamentais para um usuário em um dia específico.
    """
    # 1. Total de sessões no dia
    total_sessions = group['session_id'].nunique()
    
    # 2. Total de eventos no dia
    total_events = len(group)
    
    # 3. Apps únicos usados
    unique_apps = group['app_name'].nunique()
    
    # 4. Proporção de uso noturno (00h-05h)
    night_events = group[group['hour'].between(0, 4)]
    night_usage_ratio = len(night_events) / len(group) if len(group) > 0 else 0
    
    # 5. Duração média das sessões (estimada)
    # Para cada sessão, calculamos a diferença entre primeiro e último evento
    session_durations = []
    for sid, session_group in group.groupby('session_id'):
        if len(session_group) >= 2:
            duration = (session_group['timestamp'].max() - session_group['timestamp'].min()).total_seconds()
            session_durations.append(duration)
    avg_session_duration = np.mean(session_durations) if session_durations else 0
    
    # 6. Proporção de sessões muito curtas (<10 segundos)
    short_sessions = sum(1 for d in session_durations if d < 10)
    short_session_ratio = short_sessions / len(session_durations) if session_durations else 0
    
    # 7. Concentração no app mais usado (%)
    app_counts = group['app_name'].value_counts()
    top_app_ratio = app_counts.iloc[0] / len(group) if len(app_counts) > 0 else 0
    
    # 8. Entropia de Shannon (variedade de uso)
    # Alta entropia = uso variado; Baixa entropia = foco obsessivo em poucos apps
    app_probs = app_counts / app_counts.sum()
    app_entropy = entropy(app_probs) if len(app_probs) > 1 else 0
    
    # 9. Índice de reabertura (mesmo app aberto consecutivamente)
    opened_events = group[group['event_type'] == 'Opened'].sort_values('timestamp')
    if len(opened_events) > 1:
        consecutive_same = sum(
            1 for i in range(1, len(opened_events))
            if opened_events.iloc[i]['app_name'] == opened_events.iloc[i-1]['app_name']
        )
        reopening_index = consecutive_same / (len(opened_events) - 1)
    else:
        reopening_index = 0
    
    # 10. Intervalo médio entre sessões (minutos)
    session_starts = group.groupby('session_id')['timestamp'].min().sort_values()
    if len(session_starts) > 1:
        inter_session_gaps = session_starts.diff().dropna().dt.total_seconds() / 60
        avg_inter_session = inter_session_gaps.mean()
    else:
        avg_inter_session = 0
    
    return pd.Series({
        'total_sessions': total_sessions,
        'total_events': total_events,
        'unique_apps': unique_apps,
        'night_usage_ratio': night_usage_ratio,
        'avg_session_duration': avg_session_duration,
        'short_session_ratio': short_session_ratio,
        'top_app_ratio': top_app_ratio,
        'app_entropy': app_entropy,
        'reopening_index': reopening_index,
        'avg_inter_session': avg_inter_session
    })


# Agrupar por usuário e dia, e calcular features
daily_features = df.groupby(['user_id', 'date']).apply(
    calculate_daily_features, include_groups=False
).reset_index()

print(f"   ✅ Features calculadas!")
print(f"   📊 Total de registros (usuário-dia): {len(daily_features):,}")
print(f"   📊 Usuários: {daily_features['user_id'].nunique()}")

# ============================================================
# 3. AGREGAR POR USUÁRIO (MÉDIA DOS DIAS)
# ============================================================
print("\n📊 Agregando features por usuário (média dos dias)...")

user_features = daily_features.groupby('user_id').agg(
    # Médias das features diárias
    avg_daily_sessions=('total_sessions', 'mean'),
    avg_daily_events=('total_events', 'mean'),
    avg_unique_apps=('unique_apps', 'mean'),
    avg_night_ratio=('night_usage_ratio', 'mean'),
    avg_session_duration=('avg_session_duration', 'mean'),
    avg_short_session_ratio=('short_session_ratio', 'mean'),
    avg_top_app_ratio=('top_app_ratio', 'mean'),
    avg_entropy=('app_entropy', 'mean'),
    avg_reopening_index=('reopening_index', 'mean'),
    avg_inter_session=('avg_inter_session', 'mean'),
    # Features extras de variabilidade
    std_daily_sessions=('total_sessions', 'std'),
    max_daily_sessions=('total_sessions', 'max'),
    days_monitored=('date', 'count'),
    # Escalonamento: diferença entre primeira e segunda metade do período
).reset_index()

# Preencher NaN em std (usuários com apenas 1 dia)
user_features['std_daily_sessions'] = user_features['std_daily_sessions'].fillna(0)

print(f"   ✅ {len(user_features)} usuários com features agregadas")

# ============================================================
# 4. CALCULAR FEATURE DE ESCALONAMENTO
# ============================================================
print("\n📈 Calculando taxa de escalonamento de uso...")

def calculate_escalation(user_id, daily_data):
    """
    Compara o uso na primeira metade vs segunda metade do período monitorado.
    Valor > 1 indica escalonamento (aumento de uso ao longo do tempo).
    """
    user_days = daily_data[daily_data['user_id'] == user_id].sort_values('date')
    if len(user_days) < 4:  # Precisa de pelo menos 4 dias
        return 1.0
    
    mid = len(user_days) // 2
    first_half = user_days.iloc[:mid]['total_sessions'].mean()
    second_half = user_days.iloc[mid:]['total_sessions'].mean()
    
    if first_half > 0:
        return second_half / first_half
    return 1.0

escalation_rates = []
for uid in user_features['user_id']:
    rate = calculate_escalation(uid, daily_features)
    escalation_rates.append(rate)

user_features['escalation_rate'] = escalation_rates

print(f"   ✅ Taxa de escalonamento calculada")

# ============================================================
# 5. CRIAR LABELS DE RISCO (CLASSIFICAÇÃO)
# ============================================================
print("\n🏷️  Criando labels de risco baseadas em critérios comportamentais...")

def classify_risk(row):
    """
    Classifica o nível de risco baseado em múltiplos critérios comportamentais.
    
    Critérios para ALTO RISCO (qualquer 3 dos seguintes):
    - Uso noturno > 15% do total
    - Sessões curtas > 50% (uso compulsivo)
    - Índice de reabertura > 0.4
    - Escalonamento > 1.3 (aumento de 30%+)
    - Mais de 30 sessões/dia em média
    - Entropia muito baixa (< 1.0, foco obsessivo)
    
    Critérios para MÉDIO RISCO (qualquer 2 dos seguintes):
    - Uso noturno > 8%
    - Sessões curtas > 35%
    - Índice de reabertura > 0.25
    - Escalonamento > 1.15
    - Mais de 20 sessões/dia
    """
    risk_factors = 0
    
    # Critérios de alto risco
    if row['avg_night_ratio'] > 0.15:
        risk_factors += 1
    if row['avg_short_session_ratio'] > 0.50:
        risk_factors += 1
    if row['avg_reopening_index'] > 0.40:
        risk_factors += 1
    if row['escalation_rate'] > 1.30:
        risk_factors += 1
    if row['avg_daily_sessions'] > 30:
        risk_factors += 1
    if row['avg_entropy'] < 1.0:
        risk_factors += 1
    
    if risk_factors >= 3:
        return 2  # HIGH
    
    # Critérios de médio risco
    medium_factors = 0
    if row['avg_night_ratio'] > 0.08:
        medium_factors += 1
    if row['avg_short_session_ratio'] > 0.35:
        medium_factors += 1
    if row['avg_reopening_index'] > 0.25:
        medium_factors += 1
    if row['escalation_rate'] > 1.15:
        medium_factors += 1
    if row['avg_daily_sessions'] > 20:
        medium_factors += 1
    
    if medium_factors >= 2:
        return 1  # MEDIUM
    
    return 0  # LOW

user_features['risk_label'] = user_features.apply(classify_risk, axis=1)

# Mapear para nomes
risk_names = {0: 'LOW', 1: 'MEDIUM', 2: 'HIGH'}
user_features['risk_name'] = user_features['risk_label'].map(risk_names)

print(f"\n   📊 Distribuição de risco:")
print(f"   {'='*40}")
for label, name in risk_names.items():
    count = (user_features['risk_label'] == label).sum()
    pct = count / len(user_features) * 100
    print(f"   {name:8s}: {count:3d} usuários ({pct:.1f}%)")

# ============================================================
# 6. SALVAR RESULTADOS
# ============================================================
print("\n💾 Salvando resultados...")

# Salvar features diárias
daily_features.to_csv('features_diarias.csv', index=False)
print(f"   ✅ features_diarias.csv ({len(daily_features):,} registros)")

# Salvar features por usuário (com labels)
user_features.to_csv('features_usuarios.csv', index=False)
print(f"   ✅ features_usuarios.csv ({len(user_features)} usuários)")

# ============================================================
# 7. RESUMO DAS FEATURES
# ============================================================
print("\n" + "=" * 60)
print("RESUMO DAS FEATURES EXTRAÍDAS")
print("=" * 60)

feature_cols = ['avg_daily_sessions', 'avg_daily_events', 'avg_unique_apps',
                'avg_night_ratio', 'avg_session_duration', 'avg_short_session_ratio',
                'avg_top_app_ratio', 'avg_entropy', 'avg_reopening_index',
                'avg_inter_session', 'std_daily_sessions', 'max_daily_sessions',
                'escalation_rate']

print(f"\n{'Feature':<28s} {'Média':>10s} {'Std':>10s} {'Min':>10s} {'Max':>10s}")
print("-" * 70)
for col in feature_cols:
    mean = user_features[col].mean()
    std = user_features[col].std()
    min_val = user_features[col].min()
    max_val = user_features[col].max()
    print(f"{col:<28s} {mean:>10.2f} {std:>10.2f} {min_val:>10.2f} {max_val:>10.2f}")

print(f"""
\n{'='*60}
PRÓXIMO PASSO: Treinar o Modelo de ML (Script 03)
{'='*60}

Arquivos gerados:
  - features_diarias.csv  → Features por usuário por dia
  - features_usuarios.csv → Features agregadas + label de risco

O modelo será treinado usando 'features_usuarios.csv' com as
13 features comportamentais para classificar risco em 3 níveis.
""")
