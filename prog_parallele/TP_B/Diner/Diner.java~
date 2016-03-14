// -*- coding: utf-8 -*-

import java.util.Random;
public class Diner {    
    public static void main(String[] argv){
	Fourchette f1 = new Fourchette();
	Fourchette f2 = new Fourchette();
	Fourchette f3 = new Fourchette();
	Fourchette f4 = new Fourchette();
	Fourchette f5 = new Fourchette();	
	Philosophe p1 = new Philosophe(f5,f1,"Socrate");
	Philosophe p2 = new Philosophe(f1,f2,"Aristote");
	Philosophe p3 = new Philosophe(f2,f3,"Epicure");
	Philosophe p4 = new Philosophe(f3,f4,"Descartes");
	Philosophe p5 = new Philosophe(f4,f5,"Nietzsche");		
	p1.start();
	p2.start();
	p3.start();
	p4.start();
	p5.start();		
    }	
}
class Fourchette {	
    boolean libre;
    Thread possesseur;

    public Fourchette(){
	libre = true;
    }	
    synchronized void prendre(){	
	while ( !libre ) {
	    try { wait(); } // Le philosophe s'endort sur la fourchette!
	    catch (InterruptedException e) {
		e.printStackTrace();
	    }
	}
	possesseur = Thread.currentThread();
	libre = false;
    }
    synchronized void lacher(){
	if ( possesseur == Thread.currentThread() ){ 
	    libre = true; 
	    notifyAll();   // Réveil de tous les philosophes endormis
	}
    }
}

class Philosophe extends Thread {	
    Fourchette fg;      // La fourchette à gauche
    Fourchette fd;      // La fourchette à droite
    String nom;         // Le nom du philosophe (optionnel)
    int patience;       // Le temps de la reflexion

    public Philosophe(Fourchette fg, Fourchette fd, String nom){
	this.fg = fg;
	this.fd = fd;
	this.nom = nom;
	Random alea = new Random();
	this.patience = 1000 + alea.nextInt(5000);
    }
    public void run(){
	while(true){
	    System.out.println("[Phil] ("+this.nom+") Je pense "+patience+" ms.");
	    try { Thread.sleep(patience); }
	    catch (InterruptedException e) { e.printStackTrace(); }
	    System.out.println("[Phil] ("+this.nom+") Je suis affamé.");
	    fg.prendre();  // Le philosophe prend d'abord la fourchette à gauche
	    fd.prendre();  // Puis la fourchette à droite (pour simplifier!)
	    System.out.println("[Phil] ("+this.nom+") Je mange pendant 3s.");
	    try { Thread.sleep(3000); }
	    catch (InterruptedException e) { e.printStackTrace(); }
	    System.out.println("[Phil] ("+this.nom+") J'ai bien mangé.");
	    fg.lacher();
	    fd.lacher();
	}
    }	
}
	
/*
> javac -encoding ISO-8859-1 Diner.java
> java Diner
[Phil] (Socrate) Je pense 5308 ms.
[Phil] (Descartes) Je pense 1001 ms.
[Phil] (Epicure) Je pense 5479 ms.
[Phil] (Aristote) Je pense 3027 ms.
[Phil] (Nietzsche) Je pense 3007 ms.
[Phil] (Descartes) Je suis affamé.
[Phil] (Descartes) Je mange.
[Phil] (Nietzsche) Je suis affamé.
[Phil] (Aristote) Je suis affamé.
[Phil] (Aristote) Je mange.
[Phil] (Descartes) J'ai bien mangé.
[Phil] (Descartes) Je pense 1001 ms.
[Phil] (Nietzsche) Je mange.
[Phil] (Descartes) Je suis affamé.
[Phil] (Socrate) Je suis affamé.
[Phil] (Epicure) Je suis affamé.
[Phil] (Aristote) J'ai bien mangé.
[Phil] (Aristote) Je pense 3027 ms.
*/
