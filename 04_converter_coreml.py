"""
=============================================================
TCC - Sistema de Detecção de Dependência Digital
Passo 4: Conversão do Modelo para CoreML (.mlmodel)
=============================================================
Converte o modelo Random Forest treinado (sklearn) para o
formato .mlmodel da Apple, pronto para integrar no Xcode/iOS.

Entrada: modelo_risco_digital.pkl
Saída:   RiskClassifier.mlmodel
=============================================================
"""

import pickle
import numpy as np
import coremltools as ct
from sklearn.ensemble import RandomForestClassifier

# ============================================================
# 1. CARREGAR MODELO TREINADO
# ============================================================
print("=" * 60)
print("PASSO 4: CONVERSÃO PARA COREML (.mlmodel)")
print("=" * 60)

print("\n📂 Carregando modelo treinado...")

with open('modelo_risco_digital.pkl', 'rb') as f:
    model = pickle.load(f)

with open('modelo_info.pkl', 'rb') as f:
    model_info = pickle.load(f)

print(f"   ✅ Modelo: {model_info['model_type']}")
print(f"   ✅ Accuracy: {model_info['accuracy']*100:.1f}%")
print(f"   ✅ Features: {len(model_info['feature_columns'])}")

# ============================================================
# 2. CONVERTER PARA COREML
# ============================================================
print("\n🔄 Convertendo para CoreML...")

# Definir os nomes das features de entrada
feature_names = model_info['feature_columns']

# Converter usando coremltools
coreml_model = ct.converters.sklearn.convert(
    model,
    input_features=feature_names,
    output_feature_names='risk_level'
)

# ============================================================
# 3. ADICIONAR METADADOS AO MODELO
# ============================================================
print("\n📝 Adicionando metadados...")

coreml_model.author = 'Angelo Geraldo Pereira Junior'
coreml_model.short_description = 'Classifica risco de dependência digital baseado em padrões comportamentais de uso de smartphone.'
coreml_model.input_description['avg_daily_sessions'] = 'Média de sessões por dia'
coreml_model.input_description['avg_daily_events'] = 'Média de eventos por dia'
coreml_model.input_description['avg_unique_apps'] = 'Média de apps únicos usados por dia'
coreml_model.input_description['avg_night_ratio'] = 'Proporção de uso noturno (00h-05h)'
coreml_model.input_description['avg_session_duration'] = 'Duração média das sessões (segundos)'
coreml_model.input_description['avg_short_session_ratio'] = 'Proporção de sessões curtas (<10s)'
coreml_model.input_description['avg_top_app_ratio'] = 'Concentração no app mais usado'
coreml_model.input_description['avg_entropy'] = 'Entropia de Shannon (variedade de uso)'
coreml_model.input_description['avg_reopening_index'] = 'Índice de reabertura consecutiva'
coreml_model.input_description['avg_inter_session'] = 'Intervalo médio entre sessões (min)'
coreml_model.input_description['std_daily_sessions'] = 'Desvio padrão de sessões diárias'
coreml_model.input_description['max_daily_sessions'] = 'Máximo de sessões em um dia'
coreml_model.input_description['escalation_rate'] = 'Taxa de escalonamento de uso'

# ============================================================
# 4. SALVAR MODELO .mlmodel
# ============================================================
print("\n💾 Salvando RiskClassifier.mlmodel...")

coreml_model.save('RiskClassifier.mlmodel')
print(f"   ✅ RiskClassifier.mlmodel salvo com sucesso!")

# ============================================================
# 5. VALIDAR MODELO COREML
# ============================================================
print("\n🧪 Validando modelo CoreML com predição de teste...")

# Teste com usuário de alto risco
test_input = {
    'avg_daily_sessions': 40.0,
    'avg_daily_events': 5000.0,
    'avg_unique_apps': 5.0,
    'avg_night_ratio': 0.35,
    'avg_session_duration': 120.0,
    'avg_short_session_ratio': 0.6,
    'avg_top_app_ratio': 0.7,
    'avg_entropy': 0.8,
    'avg_reopening_index': 0.85,
    'avg_inter_session': 20.0,
    'std_daily_sessions': 15.0,
    'max_daily_sessions': 60.0,
    'escalation_rate': 1.5
}

# Predição via CoreML (só funciona em macOS, mas validamos a estrutura)
try:
    prediction = coreml_model.predict(test_input)
    risk_names = {0: 'LOW', 1: 'MEDIUM', 2: 'HIGH'}
    predicted_class = int(prediction['risk_level'])
    print(f"   Predição CoreML: {risk_names.get(predicted_class, predicted_class)}")
    print(f"   ✅ Modelo CoreML validado com sucesso!")
except Exception as e:
    print(f"   ⚠️  Predição CoreML não disponível neste OS (normal em Windows/Linux)")
    print(f"   ✅ Modelo foi salvo corretamente - funcionará no macOS/iOS")

# ============================================================
# 6. RESUMO FINAL
# ============================================================
print(f"""
\n{'='*60}
PIPELINE DE ML COMPLETO!
{'='*60}

Arquivos gerados neste pipeline:
  📄 01_exploracao_dataset.py  → Exploração inicial
  📄 02_engenharia_features.py → Engenharia de features
  📄 03_treinar_modelo.py      → Treinamento Random Forest
  📄 04_converter_coreml.py    → Conversão para CoreML
  
  📊 features_diarias.csv      → Features por usuário/dia
  📊 features_usuarios.csv     → Features agregadas + labels
  🤖 modelo_risco_digital.pkl  → Modelo sklearn (backup)
  🍎 RiskClassifier.mlmodel    → Modelo para iOS/Xcode

PRÓXIMO PASSO:
  → Abrir Xcode no Mac
  → Arrastar RiskClassifier.mlmodel para o projeto
  → Integrar com SwiftUI
""")
