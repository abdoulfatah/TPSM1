# -*- encoding: utf-8 -*-

"""
Created on Thu March 2 2016

@author: Cecile Capponi
"""

import numpy as np
from PIL import Image
import os
from numpy import load

# Affiche l'image contenu dans le fichier de nom filename,
# dans une nouvelle fenetre.
def affImage(filename):
    im = Image.open(filename)
    im.show()

# Calcule le vecteur de pixels de l'image contenue dans le fichier
# de nom filename, apres l'avoir retaillee vers un canevas de cote npix.
# Retourne donc un vecteur de taille npix*npix*3 (RGB par pixel)
def imageToVecteurPixels(filename, npix):
    im = Image.open(filename).resize((npix,npix))
    return np.reshape(np.array(im), (1, npix*npix*3))
    
# Calcule le vecteur correspondant a l'histogramme de couleurs de 
# l'image conte nue dans le fichier de nom filename. L'image est 
# supposee en couleurs (RGB)
def imageToHistogrammeCouleurs(filename):
    im = Image.open(filename)
    width, height = im.size
    return np.array(im.histogram()) / (1.0 * width * height)

# Charge et renvoie les donnees images, sous format vecteurs de pixels
# RGB, contenues dans le rep1 pour la classe t1, et dans le rep2 pour
# la classe t2.
# Les images sont retaillees, toutes a la meme dimension de taille
# sizex*sizex
# data = liste de vecteurs de pixels (un vecteur par image)
# target = liste de classes (une classe par exemple)
# n = nb total d'exemples
# taille des vecteurs (nb de composantes)
def chargementVecteursImages(rep1, rep2, t1, t2, sizex):
    data = []
    target = []
    i=0
    # parcours de tous les fichiers image du rep1 (classe t1)
    for nf in os.listdir(rep1)[1:]:
	# conversion image -> vec de pixels rgb
        data.append(imageToVecteurPixels(rep1+'/'+nf, sizex))
        target.append(t1)
        i=i+1
        j=0
        # parcours de tous les fichiers image du rep2 (classe t2)
    for nf in os.listdir(rep2)[1:]:
        data.append(imageToVecteurPixels(rep2+'/'+nf, sizex))
        target.append(t2)
        j=j+1
        n = i+j # nb d'exemples de l'echantillon
    return n, data, target, sizex*sizex*3

# Charge et renvoie les donnees images, sous format d'histogrammes
# de couleurs RGB, contenues dans le rep1 pour la classe t1, et dans 
# le rep2 pour la classe t2.
# Les vecteurs sont donc tous de la meme taille, sans que l'on ait a 
# retailler les images.
# data = liste de vecteurs de pixels (un vecteur par image)
# target = liste de classes (une classe par exemple)
# n = nb total d'exemples
# taille des vecteurs (nb de composantes)
def chargementHistogrammesImages(rep1, rep2, t1, t2):
    data = []
    target = []
    i=0
    for nf in os.listdir(rep1)[0:]:
        data.append(imageToHistogrammeCouleurs(rep1+'/'+nf))
        target.append(t1)
        i+=1
        j=0
    for nf in os.listdir(rep2)[0:]:
        data.append(imageToHistogrammeCouleurs(rep2+'/'+nf))
        target.append(t2)
        j=j+1
        n=j+i
    return n, data, target, data[0].shape[0]

# Chargement de la representation vectorielle couleur des images tests
def importVecteursTest(nf):
	return load(nf)
