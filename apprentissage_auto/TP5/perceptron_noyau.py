# -*- coding: utf-8 -*-

####################################################
#          Apprentissage supervise TP 5            #
#           III - Perceptron à noyau               #
#                Alexandre Leonardi                #
#       alexandre.leonardi@etu.univ-amu.fr         #
####################################################

#imports
import numpy as np
import math
from pylab import rand

def genererDonnees(n):
    "Generer un jeu de donnees 2D lineairement separable de taille n"
    xb=(rand(n)*2-1)/2-0.5
    yb=(rand(n)*2-1)/2+0.5
    xr=(rand(n)*2-1)/2+0.5
    yr=(rand(n)*2-1)/2-0.5
    donnees=[]
    for i in range (len(xb)):
        donnees.append(((xb[i],yb[i]),-1))
        donnees.append(((xr[i],yr[i]),1))
    return donnees

    
#2.1) Calcul du noyau gaussien de 2 vecteurs
def noyauGaussien(x1,x2,sigma):
    if x1.shape != x2.shape :
        raise Exception("Vous tentez de calculer ne noyau gaussien de 2 vecteurs de taille différente.")
    #y = np.zeros(x1.shape)
    y = x1-x2
    n = np.linalg.norm(y)
    res = math.exp(-(math.pow(n,2))/(math.pow(sigma,2)))
    return res

#2.2) Calcul du noyau polynomial de 2 vecteurs
def noyauPolynomial(x1,x2,k):
    if x1.shape != x2.shape :
        raise Exception("Vous tentez de calculer ne noyau gaussien de 2 vecteurs de taille différente.")
    if(x1.shape[0] == 1):
        y = np.dot(x1.A1,x2.A1)
    else:
        y = np.dot(x1,x2)
    y += 1
    y = math.pow(y,k)
    return y

#3.1) Création et apprentissage d'un perceptron à noyau
def signe(y):
    "Retourne le signe de y ou 0 si y est nul"
    ret = 0
    if y>0:
        ret = 1
    if y<0:
        ret = 0
    return ret

def learnKernelPerceptron(data,target,kernel,h):
    dataExt = np.matrix([np.append(d,1) for d in data])
    alpha = np.zeros(data.shape[0])
    
    #n sera le nombre d'itérations de la boucle externe : j'ai choisi un nombre d'itérations proportionnel à n*d
    #j'ai choisi comme coefficient 1/700 de manière arbitraire pour des soucis de performance
    n = data.shape[0]
    if len(data.shape)>1:
        n*=data.shape[1]
    n=10
    
    for c in range(0,n):
        for i in  range(0,data.shape[0]):
            pred = 0
            for j in range(0,data.shape[0]):
                pred += alpha[j]*target[j]*kernel(dataExt[i],dataExt[j],h)

            if signe(pred) != target[i]:
                alpha[i] += 1
    return alpha

#3.2) Prédiction de la classe d'un exemple avec un perceptron donnné
def predictKernelPerceptron(kp,i,kernel,h,data,target):
    pred = 0
    for j in range(0,data.shape[0]):
        pred += kp[j]*target[j]*kernel(data[i],data[j],h)
    return pred

def predictSet(kp,kernel,h,data,target,display):
    err=0
    i=0
    for i in  range(0,data.shape[0]):
        pred=predictKernelPerceptron(kp,i,kernel,h,data,target)
        if signe(pred) != target[i]:
            err+=1
            if display:
                print("Exemple {} : predit comme {} au lieu de {}.".format(data[i],signe(pred),target[i]))
        #i+=1
    return err


#-------------------------------------------
if __name__ == '__main__':
    #3.3) Tester predictKernelPerceptron sur les données du TP3
    apprentissage = genererDonnees(35)
    test = genererDonnees(15)
    appData = np.array([d for (d,_) in apprentissage])
    appTarget = np.array([t for (_,t) in apprentissage])
    testData = np.array([d for (d,_) in test])
    testTarget = np.array([t for (_,t) in test])
    
    print(testData.shape)
    print("________GAUSSIEN")
    tab = np.arange(0.1,1.1,0.1)
    for h in tab:
        err=0
        kp = learnKernelPerceptron(appData,appTarget,noyauGaussien,h)
        err = predictSet(kp,noyauGaussien,h,testData,testTarget,False)
        print("{:1.1f}->{}({:3.2f}%)".format(h,err,(err/testData.shape[0])*100))
    for h in range(1,11,2):
        err=0
        kp = learnKernelPerceptron(appData,appTarget,noyauGaussien,h)
        err = predictSet(kp,noyauGaussien,h,testData,testTarget,False)
        print("{:1.1f}->{}({:3.2f}%)".format(h,err,(err/testData.shape[0])*100))
    
    print("________POLYNOMIAL")
    tab = np.arange(0.1,1.1,0.1)
    for h in tab:
        err=0
        kp = learnKernelPerceptron(appData,appTarget,noyauPolynomial,h)
        err = predictSet(kp,noyauPolynomial,h,testData,testTarget,False)
        print("{:1.1f}->{}({:3.2f}%)".format(h,err,(err/testData.shape[0])*100))
    for h in range(1,11,2):
        err=0
        kp = learnKernelPerceptron(appData,appTarget,noyauPolynomial,h)
        err = predictSet(kp,noyauPolynomial,h,testData,testTarget,False)
        print("{:1.1f}->{}({:3.2f}%)".format(h,err,err/testData.shape[0]))
