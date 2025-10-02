import matplotlib.pyplot as plt
import numpy as np
from scipy import stats
import re

def analizar_y_visualizar_test_avalancha(
    datos_distribucion_str: str,
    datos_promedio_str: str,
    numero_de_muestras: int,
    grafico_unico: bool = True
):
    def _procesar_datos_avalancha(
        string_distribucion: str,
        string_promedio: str,
        muestras_esperadas: int
    ):
        regex = r'(\d{3}),\s*(\d{10}),\s*(\d{10}),\s*(\d{10})'

        datos_distribucion = re.findall(regex, string_distribucion)
        ocurrencias_totales = [sum(int(val) for val in registro[1:]) for registro in datos_distribucion]

        datos_promedio = re.findall(regex, string_promedio)
        promedio_s = [int(r[1]) / muestras_esperadas for r in datos_promedio]
        promedio_x = [int(r[2]) / muestras_esperadas for r in datos_promedio]
        promedio_y = [int(r[3]) / muestras_esperadas for r in datos_promedio]

        return promedio_s, promedio_x, promedio_y, ocurrencias_totales

    def _configurar_grafico_comun(ax, titulo, xlabel):
        ax.axhline(y=4.0, color='r', linestyle='--', label='Promedio Ideal (4.0 ± 0.5)', linewidth=1.5, zorder=2)
        ax.fill_between(range(65), 3.5, 4.5, color='red', alpha=0.15, label='Rango Ideal')
        ax.set_title(titulo, fontsize=10)
        ax.set_xlabel(xlabel)
        ax.set_ylabel('Promedio de bits de salida girados')
        ax.set_xlim(0, 64)
        ax.set_ylim(0, 8)
        ax.legend(fontsize=10)
        ax.set_xticks(np.arange(0, 65, 4))
        ax.set_yticks(np.arange(0, 9, 1))
        ax.grid(True, which='both', linestyle='--', linewidth=0.5)
        ax.minorticks_on()

    def _crear_grafico_avalancha(ax, datos_promedio, titulo):
        ax.stairs(datos_promedio, baseline=None, label='Giros de bit promedio', color="#629fca", linewidth=1.5, zorder=3)
        _configurar_grafico_comun(ax, titulo, 'Posición del bit de entrada (0-63)')

    def _crear_grafico_distribucion(ax, ocurrencias, muestras):
        posiciones = np.arange(len(ocurrencias))
        ax.bar(posiciones, ocurrencias, width=0.8, color="#629fca", zorder=2, label='Frecuencia observada')

        # Superponer la distribución binomial ideal
        n = len(ocurrencias) - 1
        p = 0.5
        # El total de ensayos es 3 (s,x,y) * 64 (bits) * numero_de_muestras
        total_ensayos = 3 * 64 * muestras
        dist_binomial = stats.binom.pmf(posiciones, n, p) * total_ensayos

        ax.plot(posiciones, dist_binomial, 'ro--', label='Distribución binomial ideal', zorder=4)
        ax.set_title('Distribución de bits de salida girados')
        ax.set_xlabel('Cantidad de bits de salida girados (0-8)')
        ax.set_ylabel('Frecuencia')
        ax.set_xticks(posiciones)
        ax.legend()
        ax.grid(axis='y')

    def _visualizar_resultados(
        promedios_s, promedios_x, promedios_y, ocurrencias_totales, muestras, en_un_grafico
    ):
        titulo = lambda var: f"Test de avalancha: Efecto al modificar un bit de '{var}'"
        if en_un_grafico:
            fig, axes = plt.subplots(2, 2, figsize=(16, 10))
            fig.tight_layout(pad=5.0)
            _crear_grafico_avalancha(axes[0, 0], promedios_s, titulo("S"))
            _crear_grafico_avalancha(axes[0, 1], promedios_x, titulo("X"))
            _crear_grafico_avalancha(axes[1, 0], promedios_y, titulo("Y"))
            _crear_grafico_distribucion(axes[1, 1], ocurrencias_totales, muestras)
            plt.savefig('./results/avalanche_test_analysis.png', dpi=300)
        else:
            for datos, var in [(promedios_s, "S"), (promedios_x, "X"), (promedios_y, "Y")]:
                plt.figure(figsize=(10, 5))
                ax = plt.subplot(1, 1, 1)
                _crear_grafico_avalancha(ax, datos, titulo(var))
                plt.savefig(f'./results/avalanche_test_analysis_{var}.png', dpi=300)
            plt.figure(figsize=(10, 5))
            ax_dist = plt.subplot(1, 1, 1)
            _crear_grafico_distribucion(ax_dist, ocurrencias_totales, muestras)
            plt.savefig('./results/avalanche_test_distribution.png', dpi=300)

    promedios_s, promedios_x, promedios_y, ocurrencias_totales = \
        _procesar_datos_avalancha(datos_distribucion_str, datos_promedio_str, numero_de_muestras)

    print("--- Resumen Estadístico del Test de Avalancha ---")
    promedio_global = np.mean([promedios_s, promedios_x, promedios_y])
    print(f"Promedio global de bits de salida girados: {promedio_global:.4f} (Ideal: 4.0)")
    print(f"Promedio por bit de 'S' modificado: {np.mean(promedios_s):.4f}")
    print(f"Promedio por bit de 'X' modificado: {np.mean(promedios_x):.4f}")
    print(f"Promedio por bit de 'Y' modificado: {np.mean(promedios_y):.4f}")
    print("-" * 51)

    _visualizar_resultados(
        promedios_s, promedios_x, promedios_y, ocurrencias_totales, numero_de_muestras, grafico_unico
    )

number_of_samples = 2_500_000

datos_distribucion = """
000, 0000624839, 0000625426, 0000624986 | 001, 0005000906, 0005002782, 0005005284 | 002, 0017496459, 0017497287, 0017495619
003, 0034995748, 0034992149, 0034993552 | 004, 0043758109, 0043762271, 0043750912 | 005, 0034996356, 0034997316, 0034998931
006, 0017503947, 0017492256, 0017505264 | 007, 0004998295, 0005004493, 0005000556 | 008, 0000625341, 0000626020, 0000624896
"""

datos_promedio = """
000, 0010001572, 0009995476, 0010000318 | 001, 0009998688, 0009997493, 0009996900
002, 0009998323, 0009998273, 0010000800 | 003, 0010002302, 0010001741, 0009999868
004, 0009998544, 0010000303, 0010001363 | 005, 0010001631, 0010000738, 0010001090
006, 0010002696, 0010001774, 0009999817 | 007, 0010000321, 0010002572, 0010000659
008, 0010003169, 0009996175, 0009999194 | 009, 0009999594, 0010000060, 0010005003
010, 0009999939, 0010002445, 0010003171 | 011, 0010000679, 0009997374, 0010000293
012, 0010000841, 0009996183, 0010003148 | 013, 0010001210, 0009997992, 0009993910
014, 0010000356, 0009997622, 0010001377 | 015, 0009998142, 0010001677, 0009998020
016, 0010001012, 0010003041, 0009999634 | 017, 0010003246, 0010002025, 0009994242
018, 0010003376, 0010000611, 0010000599 | 019, 0009997947, 0010000668, 0009998668
020, 0010000845, 0010001871, 0010001156 | 021, 0009999694, 0010002194, 0010004351
022, 0010002152, 0009999757, 0009996592 | 023, 0009997775, 0010000335, 0010000068
024, 0009994854, 0009998233, 0010000986 | 025, 0010003003, 0010003840, 0010000796
026, 0009998744, 0009999282, 0010002707 | 027, 0010001432, 0010001519, 0010002098
028, 0009999957, 0009999077, 0009999785 | 029, 0009995957, 0009999990, 0009997254
030, 0010000423, 0009996586, 0009999733 | 031, 0010005417, 0009995533, 0010000579
032, 0010002397, 0009999427, 0009998177 | 033, 0010001215, 0009996847, 0009998279
034, 0009994474, 0009998226, 0010000666 | 035, 0009998982, 0009998107, 0010000196
036, 0010003591, 0010001393, 0010002741 | 037, 0009997920, 0009997139, 0010002580
038, 0009997112, 0010002191, 0009998873 | 039, 0009997915, 0009999184, 0010000158
040, 0009999813, 0010001328, 0010000142 | 041, 0009997149, 0009998769, 0010000898
042, 0010000787, 0009999747, 0009997153 | 043, 0010000062, 0010003352, 0009997685
044, 0009998772, 0009999945, 0010000252 | 045, 0009999299, 0009999878, 0010001439
046, 0010002238, 0010001318, 0010002764 | 047, 0010001332, 0010000888, 0009998239
048, 0010004356, 0010000749, 0009997658 | 049, 0009998730, 0010002491, 0010002932
050, 0010000388, 0010003769, 0010003600 | 051, 0009999725, 0010003268, 0010000995
052, 0010000357, 0010004994, 0010002438 | 053, 0009996339, 0010000143, 0009998964
054, 0010002860, 0009999805, 0009999603 | 055, 0010001112, 0009997136, 0010000690
056, 0010002514, 0009998460, 0010002919 | 057, 0010000095, 0010001905, 0010000054
058, 0009998617, 0010000908, 0010000771 | 059, 0009999826, 0010001199, 0009995527
060, 0010001005, 0010000039, 0009997938 | 061, 0009996712, 0009996480, 0010000277
062, 0010000336, 0010001181, 0010001450 | 063, 0009999888, 0009999888, 0009999888
"""

# Llamar a la función principal para ejecutar el análisis
analizar_y_visualizar_test_avalancha(
    datos_distribucion, datos_promedio, number_of_samples, grafico_unico=False)