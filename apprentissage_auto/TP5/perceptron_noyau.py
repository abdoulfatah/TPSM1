# -*- coding: utf-8 -*-

####################################################
#          Apprentissage supervise TP 5            #
#           III - Perceptron à noyau               #
#                Alexandre Leonardi                #
#       alexandre.leonardi@etu.univ-amu.fr         #
####################################################

#imports
from sklearn.cross_validation import train_test_split
import random
import perceptron_data as datas
import tp5utils as utils
import numpy as np
import math

def association(target,m):
    "Remplit et retourne un tableau de strings ou la case d'indice i contient le nom de la i-eme classe. Permet d'etablir une association entre des classes de nom quelconque et des int"

    if m==0:
        raise Exception("Associations : l'argument m==0 (nombre de classes a trouver) n'est pas valide")
    
    trouvees=0
    asso=[]
    for i in range(0,len(target)):
        if not target[i][1] in asso:
            asso.append(target[i][1])
            trouvees+=1
        if trouvees==m:
            break
    if trouvees<m:
        raise Exception("Associations : il n'y a pas autant de classes qu'attendu")
    if trouvees>m:
        raise Exception("Ceci n'est pas cense arriver... plus de classes trouvees que prevu")
    return asso

#2.1) Calcul du noyau gaussien de 2 vecteurs
def noyauGaussien(x1,x2,sigma):
    if x1.shape != x2.shape :
        raise Exception("Vous tentez de calculer ne noyau gaussien de 2 vecteurs de taille différente.")
    y = np.zeros(x1.shape)
    y = x1-x2
    n = np.linalg.norm(y)
    res = math.exp(-(math.pow(n,2))/(math.pow(sigma,2)))
    return res

#2.2) Calcul du noyau polynomial de 2 vecteurs
def noyauPolynomial(x1,x2,k):
    if x1.shape != x2.shape :
        raise Exception("Vous tentez de calculer ne noyau gaussien de 2 vecteurs de taille différente.")
    y = np.dot(x1,x2)
    y += 1
    y = math.pow(y,k)
    return y

#3.1) Création et apprentissage d'un perceptron à noyau
def signe(y):
    "Retourne 1 si y>=0 et 0 sinon"
    ret = 1
    if y<0:
        ret = 0
    return ret

def learnKernelPerceptron(data,target,classes,kernel,h):
    dataExt = np.matrix([np.append(d,1) for d in data])
    alpha = np.zeros(data.shape[0])
    
    #n sera le nombre d'itérations de la boucle externe : j'ai choisi un nombre d'itérations proportionnel à n*d
    #j'ai choisi comme coefficient 1/700 de manière arbitraire pour des soucis de performance
    n = data.shape[0]
    if len(data.shape)>1:
        n*=data.shape[1]
    n//=700
    
    for c in range(0,n):
        for i in  range(0,data.shape[0]):
            pred = 0
            for j in range(0,data.shape[0]):
                pred += alpha[j]*target[j]*kernel(data[i],data[j],h)
            if signe(pred) != classes.index(target[i]):
                alpha[i] += 1
    return alpha

#3.2) Prédiction de la classe d'un exemple avec un perceptron donnné
def predictKernelPerceptron(kp,x,kernel,h,data,target):
    pred = 0
    for j in range(0,data.shape[0]):
        pred += kp[j]*target[j]*kernel(x,data[j],h)
    return pred

def predictSet(kp,kernel,h,data,target,classes,display):
    err=0
    i=0
    for x in data:
        pred=predictKernelPerceptron(kp,x,kernel,h,data,target)
        print(pred)
        if signe(pred) != classes.index(target[i]):
            err+=1
            if display:
                print("Exemple {} : predit comme {} au lieu de {}.".format(x,classes[signe(pred)],target[i]))
        i+=1
    return err


#-------------------------------------------
#Tableau regroupant l'ensemble des classes possibles w.r.t. l'ensemble S
#Une classe est arbitrairement definie comme la 1ere et se trouve dans la case 0, etc
classes = association(datas.bias,2)

#3.3) Tester predictKernelPerceptron sur les données Iris
train,test=train_test_split(datas.bias,test_size=0.3,random_state=random.seed())
dataTrain = np.array([d[0] for d in train])
targetTrain = np.array([d[1] for d in train])
dataTest = np.array([d[0] for d in test])
targetTest = np.array([d[1] for d in test])

h=1
kp = learnKernelPerceptron(dataTrain,targetTrain,classes,noyauGaussien,h)
err = predictSet(kp,noyauGaussien,h,dataTest,targetTest,classes,False)
print(err)
print(dataTest.shape)
