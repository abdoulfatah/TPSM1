# -*- coding: utf-8 -*-

####################################################
#          Apprentissage supervise TP 5            #
#         III - Classification d'images            #
#                Alexandre Leonardi                #
#       alexandre.leonardi@etu.univ-amu.fr         #
####################################################

#imports
import numpy as np
import random
import time
import tp5utils as utils
import perceptron_noyau as kp
from  sklearn.linear_model import Perceptron
from sklearn.svm import LinearSVC
from sklearn.cross_validation import train_test_split
from sklearn.neighbors import KNeighborsClassifier
from sklearn.tree import DecisionTreeClassifier

#Chemins vers les répertoires d'images
mer = "./Data/Mer"
ailleurs = "./Data/Ailleurs"
 
def perceptron_vecteur():
    "Interprétation des images comme vecteurs de pixels et classification via le Perceptron"
    alphas = np.arange(0.01,1.01,0.1)
    best=np.zeros(5)
    
    for npix in range(50,200,50):
        _, data, target, _ = utils.chargementVecteursImages(mer,ailleurs,1,-1,npix)
        X_train,X_test,Y_train,Y_test=train_test_split(data,target,test_size=0.3,random_state=random.seed())
        
        
        for iterations in range(1,5):
            for a in alphas:
                start_time = time.time()
                
                p = Perceptron(alpha=a, n_iter=iterations, random_state=random.seed(), n_jobs=-1)
                
                #X_train, etc, sont des tableaux à 3 dimensiosn par défaut, (93,1,30000) par exemple, qu'il faut remmener en 2 dimensions
                x1=np.array(X_train)
                x1 = np.reshape(x1, (x1.shape[0],x1.shape[2]))
                x2=np.array(X_test)
                x2 = np.reshape(x2, (x2.shape[0],x2.shape[2]))
                
                p.fit(X=x1, y=Y_train)
                score = p.score(x2,Y_test)
                
                end_time = time.time()
                if score>best[0]:
                    best[0] = score
                    best[1] = a
                    best[2] = iterations
                    best[3] = end_time-start_time
                    best[4] = npix
        
    print("| Perceptron simple              | V.Pix {:4.0f} | alpha={:1.2f} iterations={:1.0f}              | {:10.3f}ms | {:1.3f} |".format(best[4],best[1],best[2],best[3]*1000,best[0]))
    
def perceptron_noyau_vecteur():
    "Interprétation des images comme vecteurs de pixels et classification via le Perceptron à noyau"
    alphas = np.arange(0.01,1.01,0.5)
    best=np.zeros(6)
    
    for npix in range(50,200,50):
        _, data, target, _ = utils.chargementVecteursImages(mer,ailleurs,1,-1,npix)
        X_train,X_test,Y_train,Y_test=train_test_split(data,target,test_size=0.3,random_state=random.seed())
        
        
        for iterations in range(1,2):
            for a in alphas:
                start_time = time.time()
                
                x1=np.array(X_train)
                x1 = np.reshape(x1, (x1.shape[0],x1.shape[2]))
                x2=np.array(X_test)
                x2 = np.reshape(x2, (x2.shape[0],x2.shape[2]))
                
                p = kp.learnKernelPerceptron(x1, Y_train, kp.noyauGaussien, a)
                score = 1 - (kp.predictSet(p, kp.noyauGaussien, a, x2, Y_test, False)/len(Y_test))
                
                end_time = time.time()
                if score>best[0]:
                    best[0] = score
                    best[1] = a
                    best[2] = iterations
                    best[3] = end_time-start_time
                    best[4] = npix
                    best[5] = 0
                    
                """start_time = time.time()
                
                x1=np.array(X_train)
                x1 = np.reshape(x1, (x1.shape[0],x1.shape[2]))
                x2=np.array(X_test)
                x2 = np.reshape(x2, (x2.shape[0],x2.shape[2]))
                
                p = kp.learnKernelPerceptron(x1, Y_train, kp.noyauPolynomial, a)
                score = 1 - (kp.predictSet(p, kp.noyauPolynomial, a, x2, Y_test, False)/len(Y_test))
                
                end_time = time.time()
                if score>best[0]:
                    best[0] = score
                    best[1] = a
                    best[2] = iterations
                    best[3] = end_time-start_time
                    best[4] = npix
                    best[5] = 1"""
    nom = ["noyau gaussien  ","noyau polynomial"] 
    print("| Perceptron {}    | V.Pix {:4.0f} | alpha={:1.2f} iterations={:1.0f}              | {:10.3f}ms | {:1.3f} |".format(nom[int(best[5])],best[4],best[1],best[2],best[3]*1000,best[0]))

def svm_vecteur():
    "Interprétation des images comme vecteurs de pixels et classification via le SVM"
    best=np.zeros(4)
    
    for npix in range(50,200,50):
        _, data, target, _ = utils.chargementVecteursImages(mer,ailleurs,1,-1,npix)
        X_train,X_test,Y_train,Y_test=train_test_split(data,target,test_size=0.3,random_state=random.seed())
        
        for iterations in range(250,1000,250):
            start_time = time.time()
            svc = LinearSVC(random_state=random.seed(), max_iter=iterations)
            
            x1=np.array(X_train)
            x1 = np.reshape(x1, (x1.shape[0],x1.shape[2]))
            x2=np.array(X_test)
            x2 = np.reshape(x2, (x2.shape[0],x2.shape[2]))
                
            svc.fit(X=x1, y=Y_train)
            score = svc.score(x2,Y_test)
                
            end_time = time.time()
            if score>best[0]:
                best[0] = score
                best[1] = iterations
                best[2] = end_time-start_time
                best[3] = npix
    
    print("| SVM linéaire                   | V.Pix {:4.0f} | iterations={:1.0f}                       | {:10.3f}ms | {:1.3f} |".format(best[3],best[1],best[3]*1000,best[0]))

def kppv_vecteur():
    "Interprétation des images comme vecteurs de pixels et classification via les k plus proches voisins"
    best = np.zeros(6)    
    
    for npix in range(50,200,50):
        _, data, target, _ = utils.chargementVecteursImages(mer,ailleurs,1,-1,npix)
        X_train,X_test,Y_train,Y_test=train_test_split(data,target,test_size=0.3,random_state=random.seed())
        
        for iterations in range(250,1000,250):
            for n in range(2,12,2):
                for param in range (1,3):
                    start_time = time.time()
                    kppv = KNeighborsClassifier(n_neighbors=n, p=param, n_jobs=-1)
                    
                    x1=np.array(X_train)
                    x1 = np.reshape(x1, (x1.shape[0],x1.shape[2]))
                    x2=np.array(X_test)
                    x2 = np.reshape(x2, (x2.shape[0],x2.shape[2]))
                        
                    kppv.fit(X=x1, y=Y_train)
                    score = kppv.score(x2,Y_test)
                        
                    end_time = time.time()
                    if score>best[0]:
                        best[0] = score
                        best[1] = iterations
                        best[2] = n
                        best[3] = param
                        best[4] = end_time-start_time
                        best[5] = npix
    
    print("| K plus proches voisins         | V.Pix {:4.0f} | n={:1.0f} param={:1.0f} iterations={:1.0f}           | {:10.3f}ms | {:1.3f} |".format(best[5],best[2],best[3],best[1],best[4]*1000,best[0]))
    

#Définition et appel du main

def arbre_decision_vecteur():
    "Interprétation des images comme vecteurs de pixels et classification via un arbre de décision"
    best = np.zeros(6)
    nom = ["gini","entr"]    
    depths = [10,200,1000]
    
    for npix in range(50,200,50):
        _, data, target, _ = utils.chargementVecteursImages(mer,ailleurs,1,-1,npix)
        X_train,X_test,Y_train,Y_test=train_test_split(data,target,test_size=0.3,random_state=random.seed())
        for d in depths:
            for m in range(1, 5, 2):        
                start_time = time.time()
                ad = DecisionTreeClassifier(max_depth=d, min_samples_leaf=m, random_state=random.seed(), presort=True)
                
                x1 = np.array(X_train)
                x1 = np.reshape(x1, (x1.shape[0], x1.shape[2]))
                x2 = np.array(X_test)
                x2 = np.reshape(x2, (x2.shape[0], x2.shape[2]))
                    
                ad.fit(X=x1, y=Y_train)
                score = ad.score(x2, Y_test)
                    
                end_time = time.time()
                if score > best[0]:
                    best[0] = score
                    best[1] = d
                    best[2] = m
                    best[3] = npix
                    best[4] = end_time - start_time
                    best[5] = 0
                    
                start_time = time.time()
                ad = DecisionTreeClassifier(criterion="entropy", max_depth=d, min_samples_leaf=m, random_state=random.seed(), presort=True)
                
                x1 = np.array(X_train)
                x1 = np.reshape(x1, (x1.shape[0], x1.shape[2]))
                x2 = np.array(X_test)
                x2 = np.reshape(x2, (x2.shape[0], x2.shape[2]))
                    
                ad.fit(X=x1, y=Y_train)
                score = ad.score(x2, Y_test)
                    
                end_time = time.time()
                if score > best[0]:
                    best[0] = score
                    best[1] = d
                    best[2] = m
                    best[3] = npix
                    best[4] = end_time - start_time
                    best[5] = 1

    print("| Arbre de décision ({})       | V.Pix {:4.0f} | prof max={:4.0f}, elts par feuille={:2.0f}   | {:10.3f}ms | {:1.3f} |".format(nom[int(best[5])],best[3],best[1],best[2],best[4]*1000,best[0]))

def perceptron_histo():
    "Interprétation des images comme histogrammes de couleurs et classification via le Perceptron"
    alphas = np.arange(0.01,1.01,0.1)
    best=np.zeros(4)
    
    _, data, target, _ = utils.chargementHistogrammesImages(mer,ailleurs,1,-1)
    X_train,X_test,Y_train,Y_test=train_test_split(data,target,test_size=0.3,random_state=random.seed())
    
    
    for iterations in range(1,5):
        for a in alphas:
            start_time = time.time()
            
            p = Perceptron(alpha=a, n_iter=iterations, random_state=random.seed(), n_jobs=-1)
            
            x1=np.array(X_train)
            x2=np.array(X_test)
            
            p.fit(X=x1, y=Y_train)
            score = p.score(x2,Y_test)
            
            end_time = time.time()
            if score>best[0]:
                best[0] = score
                best[1] = a
                best[2] = iterations
                best[3] = end_time-start_time
        
    print("| Perceptron simple               | V.Histo    | alpha={:1.2f} iterations={:1.0f}            | {:10.3f}ms | {:1.3f} |".format(best[1],best[2],best[3]*1000,best[0]))
    
def perceptron_noyau_histo():
    "Interprétation des images comme histogrammes de couleurs et classification via le Perceptron à noyau"
    alphas = np.arange(0.01,1.01,0.5)
    best=np.zeros(5)
    
    _, data, target, _ = utils.chargementHistogrammesImages(mer,ailleurs,1,-1)
    X_train,X_test,Y_train,Y_test=train_test_split(data,target,test_size=0.3,random_state=random.seed())
    
    
    for iterations in range(1,2):
        for a in alphas:
            start_time = time.time()
            
            x1=np.array(X_train)
            x2=np.array(X_test)
            
            p = kp.learnKernelPerceptron(x1, Y_train, kp.noyauGaussien, a)
            score = 1 - (kp.predictSet(p, kp.noyauGaussien, a, x2, Y_test, False)/len(Y_test))
            
            end_time = time.time()
            if score>best[0]:
                best[0] = score
                best[1] = a
                best[2] = iterations
                best[3] = end_time-start_time
                best[4] = 0
                
            """start_time = time.time()
            
            x1=np.array(X_train)
            x1 = np.reshape(x1, (x1.shape[0],x1.shape[2]))
            x2=np.array(X_test)
            x2 = np.reshape(x2, (x2.shape[0],x2.shape[2]))
            
            p = kp.learnKernelPerceptron(x1, Y_train, kp.noyauPolynomial, a)
            score = 1 - (kp.predictSet(p, kp.noyauPolynomial, a, x2, Y_test, False)/len(Y_test))
            
            end_time = time.time()
            if score>best[0]:
                best[0] = score
                best[1] = a
                best[2] = iterations
                best[3] = end_time-start_time
                best[4] = npix
                best[5] = 1"""
    nom = ["noyau gaussien  ","noyau polynomial"] 
    print("| Perceptron {}     | V.Histo    | alpha={:1.2f} iterations={:1.0f}            | {:10.3f}ms | {:1.3f} |".format(nom[int(best[4])],best[1],best[2],best[3]*1000,best[0]))

def svm_histo():
    "Interprétation des images comme histogrammes de couleurs et classification via le SVM"
    best=np.zeros(3)
    
    _, data, target, _ = utils.chargementHistogrammesImages(mer,ailleurs,1,-1)
    X_train,X_test,Y_train,Y_test=train_test_split(data,target,test_size=0.3,random_state=random.seed())
    
    for iterations in range(250,1000,250):
        start_time = time.time()
        svc = LinearSVC(random_state=random.seed(), max_iter=iterations)
        
        x1=np.array(X_train)
        x2=np.array(X_test)
            
        svc.fit(X=x1, y=Y_train)
        score = svc.score(x2,Y_test)
            
        end_time = time.time()
        if score>best[0]:
            best[0] = score
            best[1] = iterations
            best[2] = end_time-start_time
    
    print("| SVM linéaire                    | V.Histo    | iterations={:1.0f}                     | {:10.3f}ms | {:1.3f} |".format(best[1],best[2]*1000,best[0]))

def kppv_histo():
    "Interprétation des images comme histogrammes de couleurs et classification via les k plus proches voisins"
    best = np.zeros(5)    
    
    _, data, target, _ = utils.chargementHistogrammesImages(mer,ailleurs,1,-1)
    X_train,X_test,Y_train,Y_test=train_test_split(data,target,test_size=0.3,random_state=random.seed())
    
    for iterations in range(250,1000,250):
        for n in range(2,12,2):
            for param in range (1,3):
                start_time = time.time()
                kppv = KNeighborsClassifier(n_neighbors=n, p=param, n_jobs=-1)
                
                x1=np.array(X_train)
                x2=np.array(X_test)
                    
                kppv.fit(X=x1, y=Y_train)
                score = kppv.score(x2,Y_test)
                    
                end_time = time.time()
                if score>best[0]:
                    best[0] = score
                    best[1] = iterations
                    best[2] = n
                    best[3] = param
                    best[4] = end_time-start_time
    
    print("| K plus proches voisins          | V.Histo    | n={:1.0f} param={:1.0f} iterations={:1.0f}         | {:10.3f}ms | {:1.3f} |".format(best[2],best[3],best[1],best[4]*1000,best[0]))
    

def arbre_decision_histo():
    "Interprétation des images comme histogrammes de couleurs et classification via un arbre de décision"
    best = np.zeros(5)
    nom = ["gini","entr"]    
    depths = [10,200,1000]
    
    _, data, target, _ = utils.chargementHistogrammesImages(mer,ailleurs,1,-1)
    X_train,X_test,Y_train,Y_test=train_test_split(data,target,test_size=0.3,random_state=random.seed())
    for d in depths:
        for m in range(1, 5, 2):        
            start_time = time.time()
            ad = DecisionTreeClassifier(max_depth=d, min_samples_leaf=m, random_state=random.seed(), presort=True)
            
            x1 = np.array(X_train)
            x2 = np.array(X_test)
                
            ad.fit(X=x1, y=Y_train)
            score = ad.score(x2, Y_test)
                
            end_time = time.time()
            if score > best[0]:
                best[0] = score
                best[1] = d
                best[2] = m
                best[3] = end_time - start_time
                best[4] = 0
                
            start_time = time.time()
            ad = DecisionTreeClassifier(criterion="entropy", max_depth=d, min_samples_leaf=m, random_state=random.seed(), presort=True)
            
            x1 = np.array(X_train)
            x2 = np.array(X_test)
                
            ad.fit(X=x1, y=Y_train)
            score = ad.score(x2, Y_test)
                
            end_time = time.time()
            if score > best[0]:
                best[0] = score
                best[1] = d
                best[2] = m
                best[3] = end_time - start_time
                best[4] = 1

    print("| Arbre de décision ({})        | V.Histo    | prof max={:4.0f}, elts par feuille={:2.0f} | {:10.3f}ms | {:1.3f} |".format(nom[int(best[4])],best[1],best[2],best[3]*1000,best[0]))

#Définition et appel du main
def main():
    #Représentation sous forme vectorielle
    perceptron_vecteur()
    perceptron_noyau_vecteur()
    svm_vecteur()
    kppv_vecteur()
    arbre_decision_vecteur()
    
    #Représentation sous forme d'histogramme
    perceptron_histo()
    perceptron_noyau_histo()
    svm_histo()
    kppv_histo()
    arbre_decision_histo()

    
if __name__ == '__main__':
    main()

#Réponse à la question
"""
L'algorithme le plus efficace semble être le Perceptron simple qui offre un score oscillant entre 900 et 925 en un temps d'exécution court (10 à 20ms).
Cependant, il faut noter que ma version de perceptron à noyau ne fonctionne pas correctement, et qu'il n'y a pas de version de cet algo proposée par scikit learn.
Il est aussi à noter que les très longs temps d'exécution de certains des algorithmes ne me permettent pas de tester des variations sur tous les paramètres disponibles
(ou alors en nombre limité seulement) en un temps raisonnable. 
Pour la même raison, je n'ai pas pu relancer les tests de nombreuses fois consécutives pour vérifier la suprématie du Perceptron simple. 
"""

#Exemple de tableau récapitulatif
"""
| Perceptron simple               | V.Pix  100 | alpha=0.01 iterations=4            |     43.032ms | 0.900 |
| Perceptron noyau gaussien       | V.Pix  100 | alpha=0.51 iterations=1            |   6172.861ms | 0.575 |
| SVM linéaire                    | V.Pix  150 | iterations=250                     | 150000.000ms | 0.850 |
| K plus proches voisins          | V.Pix  100 | n=10 param=2 iterations=250        |    141.607ms | 0.900 |
| Arbre de décision (gini)        | V.Pix   50 | prof max=  10, elts par feuille= 3 |    105.566ms | 0.850 |
| Perceptron simple               | V.Histo    | alpha=0.11 iterations=1            |      1.500ms | 0.854 |
| Perceptron noyau gaussien       | V.Histo    | alpha=0.51 iterations=1            |   2613.722ms | 0.610 |
| SVM linéaire                    | V.Histo    | iterations=250                     |      7.505ms | 0.805 |
| K plus proches voisins          | V.Histo    | n=8 param=1 iterations=250         |    105.006ms | 0.780 |
| Arbre de décision (entr)        | V.Histo    | prof max=1000, elts par feuille= 1 |     41.028ms | 0.878 |
"""