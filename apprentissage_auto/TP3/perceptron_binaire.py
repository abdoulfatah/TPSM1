####################################################
#          Apprentissage supervise TP 3            #
#   I - Algorithme de perception pour la           #
#            classification binaire                #
#           Alexandre Leonardi                     #
#      alexandre.leonardi@etu.univ-amu.fr          #
####################################################

#imports
import numpy as np
import perceptron_data as datas
from pylab import rand,plot,show,norm

def perceptronBinaireDim1(S,N):
    "A partir d'un ensemble S d'exemples, cree un classifieur binaire W a l'aide de la methode du perceptron. Les elements de S n'ont qu'une seule valeur associee"
    if not S:
        print("Tentative de classer un ensemble vide d'exemples !")
        return
    W=[0]
    b=0
    for i in range(0,N):
        for index,(x,y_brut) in enumerate(S):
            pred=np.dot(W,x)
            y=0
            if y_brut:
                y=1
                b=(b+x)/2
            else:
                y=-1
                b=(b-x)/2
            if y*pred+b<=0:
                if y>0:
                    W[0]+=x
                elif y<0:
                    W[0]-=x
                else:
                    print("L'element d'indice ", index," a une etiquette nulle !")
    return W               

def perceptronBinaire(S,N):
    "A partir d'un ensemble S d'exemples, cree un classifieur binaire W a l'aide de la methode du perceptron"
    if not S: 
        print("Tentative de classer en ensemble vide d'exemples !")
        return
    W=[0]*len(S[0][0])
    b=0
    for i in range(0,N):
        for index,(x,y_brut) in enumerate(S):
            pred = np.dot(W,x)
            y=0
            if y_brut: 
                y=1
                b=(b+(sum(x)/len(x)))/2
            else: 
                y=-1
                b=(b-(sum(x)/len(x)))/2
            if y*pred+b<=0:
                if y>0:
                    for j in range(0,len(W)): 
                        W[j]+=x[j]
                elif y<0:
                    for j in range(0,len(W)):
                        W[j]-=x[j]
                else:
                    print("L'element d'indice ", index," a une etiquette nulle !")
    return W

def genererDonnees(n):
    "Generer un jeu de donnees 2D lineairement separable de taille n"
    xb=(rand(n)*2-1)/2-0.5
    yb=(rand(n)*2-1)/2+0.5
    xr=(rand(n)*2-1)/2+0.5
    yr=(rand(n)*2-1)/2-0.5
    donnees=[]
    for i in range (len(xb)):
        donnees.append(((xb[i],yb[i]),False))
        donnees.append(((xr[i],yr[i]),True))
    return donnees

def calculErreurs(W,S):
    "Calcule et affiche le taux d'erreurs de la classification de S par W"
    erreurs=0
    n = len(S)/len(S[0])
    for i in range(0,int(n)):
        tmp = np.dot(W,S[i][0])
        #print(tmp,S[i][1])
        if tmp>0 and not S[i][1]: 
            erreurs+=1
        elif tmp<0 and S[i][1]: 
            erreurs+=1
            print(erreurs/(len(S)/len(S[0]))*100,"% d'erreurs")
    return

#Generation des ensembles d'apprentissage et de test et du vecteur de classification
apprentissage = genererDonnees(100)
test = genererDonnees(50)
W = perceptronBinaire(apprentissage,10)
Wbiais = perceptronBinaireDim1(datas.bias,10)

#Calcul des taux d'erreurs de W, a priori 0
calculErreurs(W,apprentissage)
calculErreurs(W,test)

#Affichage des ensembles et de W
"""for x in apprentissage:
    if x[1]:
        plot(x[0][0],x[0][1],'ob')
    else:
        plot(x[0][0],x[0][1],'or')

plot(W[0],W[1],'og')"""

#Affichage de datas.bias
for x in datas.bias:
    if x[1]:
        plot(x[0],0,'ob')
    else:
        plot(x[0],0,'or')

#Debut : Copie a partir de la correction car je ne trouvais pas comment afficher la droite
"""n = norm(W)
ww = W/n
ww1 = [ww[1],-ww[0]]
ww2 = [-ww[1],ww[0]]
plot([ww1[0], ww2[0]],[ww1[1], ww2[1]],'--k')"""
plot([Wbiais[0]+0.45,Wbiais[0]+0.45],[-10,10],'--k')
#Fin



show()
