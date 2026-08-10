import subprocess
import sys
from pathlib import Path

from marriage_early_stopping import RelationshipState


def test_relationship_state_copy_is_independent():
    original = RelationshipState("вечер с сериалом и чаем")
    copy = original.copy()
    copy.load(RelationshipState("другое состояние"))
    assert str(original) == "вечер с сериалом и чаем"
    assert str(copy) == "другое состояние"


def test_load_mutates_in_place():
    state = RelationshipState("начало")
    state.load(RelationshipState("конец"))
    assert str(state) == "конец"


def test_demo_scenario_output_matches_python_original_wording():
    # Обвязка сама себя запускает только под `if __name__ == "__main__"`,
    # поэтому демо-сценарий проверяем как реальный подпроцесс, а не импортом.
    script = Path(__file__).parent.parent / "marriage_early_stopping.py"
    result = subprocess.run(
        [sys.executable, str(script)], capture_output=True, text=True, check=True
    )
    assert result.stdout == (
        "Чекпоинт сохранен: атмосфера идеальная. Веса зафиксированы.\n"
        "Чекпоинт сохранен: атмосфера идеальная. Веса зафиксированы.\n"
        "Внимание: замечен оверфит. Счетчик: 1/3\n"
        "Внимание: замечен оверфит. Счетчик: 2/3\n"
        "Внимание: замечен оверфит. Счетчик: 3/3\n"
        "🚨 Критический оверфит! Инициирую сброс до стабильного чекпоинта...\n"
        "🔄 Модель успешно откачена до состояния 'Любимый человек'. Обучение продолжается.\n"
    )
