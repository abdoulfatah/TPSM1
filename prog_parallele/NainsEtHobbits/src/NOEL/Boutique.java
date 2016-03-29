// -*- coding: utf-8 -*-

package NOEL;

import java.util.Random;

public class Boutique{
    final static int nbRennes = 9;

    /* Début du code à modifier */
    final static int nbElfes = 3;

    public void dormir(){}
    public boolean tousLesRennesSontRentres(){return(false);}
    public void retourner(){}
    public void partirEnVacances(){}
    public void relacherLesRennes(){}
    public boolean troisElfesOntUnSouci(){return(false);}
    public void demanderDeLAide(){}
    public void retournerAuTravail(){}
    public void renvoyerLesElfes(){}
           
    /* Fin du code à modifier */

    public static void main(String[] args){
	Boutique laBoutique = new Boutique();
	new PereNoel(laBoutique).start();
	for(int i=0; i<nbRennes; i++) new Renne(laBoutique).start();
	for(int i=0; i<nbElfes; i++) new Elfe(laBoutique).start();
    }    
}    

class PereNoel extends Thread{
    public Boutique laBoutique;
    public PereNoel(Boutique b){
	this.laBoutique = b;
    }
    public void run(){
	while(true){
	    System.out.println("[PN] Le père Noël s'endort.");
	    laBoutique.dormir();
	    System.out.println("[PN] Le père Noël se réveille.");
	    if (laBoutique.tousLesRennesSontRentres()) {
		try {
		    System.out.println("[PN] Le père Noël installe le traineau.");
		    sleep(333);
		    System.out.println("[PN] Le père Noël charge le traineau.");
		    sleep(333);
		    System.out.println("[PN] Le père Noël distribue les cadeaux.");
		    sleep(334);
		    System.out.println("[PN] Le père Noël relâche les rennes."); }
		catch (InterruptedException e) {e.printStackTrace();}
		laBoutique.relacherLesRennes();
	    }
	    else {
		if (laBoutique.troisElfesOntUnSouci()) {
		    System.out.println("[PN] Le père Noël reçoit les trois elfes.");
		    try { sleep(1000); } 
		    catch (InterruptedException e) {e.printStackTrace();}
		    System.out.println("[PN] Le père Noël renvoie les trois elfes."); 
		    laBoutique.renvoyerLesElfes();
		}
		else {
		    System.out.println("[PN] Bouh! Le père Noël s'est réveillé pour rien!");
		    System.exit(1);
		}
	    }	
	}
    }
}

class Renne extends Thread{
    public Boutique laBoutique;
    public Renne(Boutique b){
	this.laBoutique = b;
    }
    public void run(){
	while(true){
	    try {sleep(11000);}
	    catch (InterruptedException e) {e.printStackTrace();}
	    System.out.println("[R] Je rentre au pôle nord.");
	    laBoutique.retourner();
	    laBoutique.partirEnVacances();
	    System.out.println("[R] Je pars au soleil.");
	}
    }	
}

class Elfe extends Thread{
    public Boutique laBoutique;
    public Elfe(Boutique b){
	this.laBoutique = b;
    }
    public void run(){
	Random alea = new Random();
	while(true){
	    try {sleep(500+alea.nextInt(10)*500);}
	    catch (InterruptedException e) {e.printStackTrace();}
	    System.out.println("[E] J'ai besoin d'aide.");
	    laBoutique.demanderDeLAide();
	    laBoutique.retournerAuTravail();
	    System.out.println("[E] Je retourne au travail.");
	}
    }	
}

