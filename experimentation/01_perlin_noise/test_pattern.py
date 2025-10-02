import numpy as np
import matplotlib.pyplot as plt
from PIL import Image
import os

def display_pattern_images(images_route, seed, x, y):
    configs = [
        ('seed', seed, 'pattern_sy.png', "Semilla", "Coordenada Y"),
        ('x', x, 'pattern_xs.png', "Coordenada X", "Semilla"),
        ('y', y, 'pattern_xy.png', "Coordenada X", "Coordenada Y")
    ]
    
    fig, axes = plt.subplots(1, 3, figsize=(15, 5), constrained_layout=True)
    fig.suptitle("Comparación de imágenes cargadas", fontsize=16)

    im = None
    for i, (param, value, filename, xlabel, ylabel) in enumerate(configs):
        image_path = os.path.join(images_route, filename)
        
        if not os.path.exists(image_path):
            print(f"Error: No se encontró la imagen en: {image_path}")
            return
        
        # Load and process image
        image = Image.open(image_path)
        if image.mode != 'L':
            image = image.convert('L')
        image_data = np.array(image)
        
        # Setup subplot
        axes[i].set_xlabel(xlabel)
        axes[i].set_ylabel(ylabel)
        im = axes[i].imshow(image_data, cmap='gray', origin='lower')
        axes[i].set_title(f"'{param}' fijo en {value}")
        
        # Configure axis ticks
        image_size = image_data.shape[0]
        axes[i].set_xticks(np.arange(0, image_size + 1, 32))
        axes[i].set_yticks(np.arange(0, image_size + 1, 32))
        
        print(f"Imagen cargada desde '{image_path}'")

    # Add colorbar and save
    fig.colorbar(im, ax=axes.tolist(), label="Valor de la imagen", shrink=0.825, aspect=10, pad=0.04)
    plt.savefig("./results/test_pattern_results.png", dpi=300)
    print("Imagen combinada guardada como 'test_pattern_results.png'")

# Ejecuta la función principal con la ruta de las imágenes
display_pattern_images("./results/", 0, 0, 0)