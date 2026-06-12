"""
=============================================================
TCC - Sistema de Detecção de Dependência Digital
Passo 3: Treinamento do Modelo (Random Forest)
=============================================================
Treina um modelo Random Forest para classificar risco de
dependência digital em 3 níveis: LOW, MEDIUM, HIGH.

Entrada: features_usuarios.csv (gerado no Passo 2)
Saída:   modelo_risco_digital.pkl (modelo treinado)
=============================================================
"""

import pandas as pd
import numpy as np
from sklearn.model_selection import StratifiedKFold, cross_val_predict
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
from sklearn.preprocessing import StandardScaler
import pickle
import warnings
warnings.filterwarnings('ignore')

# ============================================================
# 1. CARREGAR FEATURES
# ============================================================
print("=" * 60)
print("PASSO 3: TREINAMENTO DO MODELO (RANDOM FOREST)")
print("=" * 60)

print("\n📂 Carregando features_usuarios.csv...")
df = pd.read_csv('features_usuarios.csv')
print(f"   ✅ {len(df)} usuários carregados")

# ============================================================
# 2. PREPARAR DADOS PARA TREINAMENTO
# ============================================================
print("\n🔧 Preparando dados para treinamento...")

# Features que alimentam o modelo
feature_columns = [
    'avg_daily_sessions',
    'avg_daily_events',
    'avg_unique_apps',
    'avg_night_ratio',
    'avg_session_duration',
    'avg_short_session_ratio',
    'avg_top_app_ratio',
    'avg_entropy',
    'avg_reopening_index',
    'avg_inter_session',
    'std_daily_sessions',
    'max_daily_sessions',
    'escalation_rate'
]

X = df[feature_columns].values
y = df['risk_label'].values  # 0=LOW, 1=MEDIUM, 2=HIGH

print(f"   Features: {len(feature_columns)}")
print(f"   Amostras: {len(X)}")
print(f"   Classes: LOW={sum(y==0)}, MEDIUM={sum(y==1)}, HIGH={sum(y==2)}")

# ============================================================
# 3. TREINAR MODELO COM CROSS-VALIDATION
# ============================================================
print("\n🤖 Treinando Random Forest com Stratified 5-Fold Cross-Validation...")

# Configuração do modelo
model = RandomForestClassifier(
    n_estimators=100,       # 100 árvores
    max_depth=10,           # Limitar profundidade para evitar overfitting
    min_samples_split=5,    # Mínimo de amostras para dividir nó
    min_samples_leaf=3,     # Mínimo de amostras por folha
    random_state=42,        # Reprodutibilidade
    class_weight='balanced' # Balancear classes (temos poucos LOW)
)

# Cross-validation estratificada (mantém proporção das classes)
cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)

# Predições via cross-validation (cada amostra é predita quando está no fold de teste)
y_pred = cross_val_predict(model, X, y, cv=cv)

# ============================================================
# 4. AVALIAR MÉTRICAS
# ============================================================
print("\n" + "=" * 60)
print("RESULTADOS DA AVALIAÇÃO (5-Fold Cross-Validation)")
print("=" * 60)

# Accuracy geral
acc = accuracy_score(y, y_pred)
print(f"\n📊 Accuracy Geral: {acc:.4f} ({acc*100:.1f}%)")

# Classification Report
print(f"\n📊 Classification Report:")
print("-" * 60)
target_names = ['LOW (0)', 'MEDIUM (1)', 'HIGH (2)']
report = classification_report(y, y_pred, target_names=target_names)
print(report)

# Confusion Matrix
print(f"📊 Matriz de Confusão:")
print("-" * 60)
cm = confusion_matrix(y, y_pred)
print(f"{'':>12s} {'Pred LOW':>10s} {'Pred MED':>10s} {'Pred HIGH':>10s}")
for i, name in enumerate(['Real LOW', 'Real MED', 'Real HIGH']):
    print(f"{name:>12s} {cm[i][0]:>10d} {cm[i][1]:>10d} {cm[i][2]:>10d}")

# ============================================================
# 5. FEATURE IMPORTANCE
# ============================================================
print(f"\n📊 Feature Importance (quais variáveis mais influenciam):")
print("-" * 60)

# Treinar modelo final com todos os dados
model.fit(X, y)

importances = model.feature_importances_
indices = np.argsort(importances)[::-1]

for rank, idx in enumerate(indices, 1):
    bar = "█" * int(importances[idx] * 50)
    print(f"   {rank:2d}. {feature_columns[idx]:<28s} {importances[idx]:.4f} {bar}")

# ============================================================
# 6. SALVAR MODELO
# ============================================================
print(f"\n💾 Salvando modelo treinado...")

# Salvar modelo com pickle
with open('modelo_risco_digital.pkl', 'wb') as f:
    pickle.dump(model, f)
print(f"   ✅ modelo_risco_digital.pkl salvo")

# Salvar também os nomes das features (necessário para CoreML)
model_info = {
    'feature_columns': feature_columns,
    'target_names': ['LOW', 'MEDIUM', 'HIGH'],
    'accuracy': acc,
    'model_type': 'RandomForestClassifier',
    'n_estimators': 100,
    'dataset': 'LSApp (ACM TOIS 2021)',
    'n_samples': len(X)
}

with open('modelo_info.pkl', 'wb') as f:
    pickle.dump(model_info, f)
print(f"   ✅ modelo_info.pkl salvo (metadados)")

# ============================================================
# 7. TESTE RÁPIDO - SIMULAÇÃO DE PREDIÇÃO
# ============================================================
print(f"\n" + "=" * 60)
print("TESTE: SIMULAÇÃO DE PREDIÇÃO")
print("=" * 60)

# Simular um usuário de alto risco
print("\n🧪 Usuário simulado (alto risco):")
print("   - 40 sessões/dia, muito uso noturno, alta reabertura")
test_high = np.array([[40, 5000, 5, 0.35, 120, 0.6, 0.7, 0.8, 0.85, 20, 15, 60, 1.5]])
pred = model.predict(test_high)
proba = model.predict_proba(test_high)
print(f"   Predição: {target_names[pred[0]]}")
print(f"   Probabilidades: LOW={proba[0][0]:.2%}, MEDIUM={proba[0][1]:.2%}, HIGH={proba[0][2]:.2%}")

# Simular um usuário de baixo risco
print("\n🧪 Usuário simulado (baixo risco):")
print("   - 8 sessões/dia, sem uso noturno, uso variado")
test_low = np.array([[8, 200, 12, 0.02, 600, 0.1, 0.25, 2.1, 0.2, 90, 3, 12, 0.9]])
pred = model.predict(test_low)
proba = model.predict_proba(test_low)
print(f"   Predição: {target_names[pred[0]]}")
print(f"   Probabilidades: LOW={proba[0][0]:.2%}, MEDIUM={proba[0][1]:.2%}, HIGH={proba[0][2]:.2%}")

print(f"""
\n{'='*60}
PRÓXIMO PASSO: Converter para CoreML (Script 04)
{'='*60}

Modelo treinado com sucesso!
  - Accuracy: {acc*100:.1f}%
  - Features mais importantes identificadas
  - Modelo salvo em modelo_risco_digital.pkl

O próximo script converte o modelo para .mlmodel (CoreML)
para integração direta no app iOS via Xcode.
""")
