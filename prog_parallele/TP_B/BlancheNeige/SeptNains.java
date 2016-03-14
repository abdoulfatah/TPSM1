// -*- coding: utf-8 -*-

import java.util.*;

public class SeptNains{
    public static void main(String[] args){
	int nbNains = 7;
	BlancheNeige bn = new BlancheNeige();
	String nom [] = {"Simplet", "Dormeur",  "Atchoum", "Joyeux",
			 "Grincheux", "Prof", "Timide"};
	Nain nain [] = new Nain [nbNains];
	for(int i=0; i<nbNains; i++)
	    nain[i] = new Nain(nom[i], bn);
	for(int i=0; i<nbNains; i++)
	    nain[i].start();
    }
}    

class BlancheNeige{
    private volatile boolean libre = true;
              // Initialement, Blanche-Neige est libre.
    private volatile LinkedList<Thread> fifo = new LinkedList<>();//Liste des nains attendant leur tour avec Blanche-Neige

    public synchronized void requerir(){
	System.out.println(Thread.currentThread().getName()
			   + " veut la ressource");
    }

    public synchronized void acceder(){
	fifo.add(Thread.currentThread());
	while( !libre || fifo.indexOf(Thread.currentThread()) != 0) 
	    // Le nain s'endort sur le moniteur Blanche-Neige.
	    try { wait(); }
	    catch (InterruptedException e) {e.printStackTrace();}
	fifo.removeFirst();
	libre = false;
	System.out.println("\t" + Thread.currentThread().getName()
			   + " accède à la ressource.");
    }

    public synchronized void relacher(){
	System.out.println("\t\t" + Thread.currentThread().getName()
			   + " relâche la ressource.");
	libre = true;
	notifyAll();
    }
}

class Nain extends Thread{
    public BlancheNeige bn;
    public Nain(String nom, BlancheNeige bn){
	this.setName(nom);
	this.bn = bn;
    }
    public void run(){
	while(true){
	    bn.requerir();
	    bn.acceder();
	    try {sleep(1000);}
	    catch (InterruptedException e) {e.printStackTrace();}
	    bn.relacher();
	}
    }	
}

/*
$ javac -encoding ISO-8859-1 SeptNains.java
$ java SeptNains 
Simplet veut la ressource
        Simplet accède à la ressource.
Atchoum veut la ressource
Timide veut la ressource
Joyeux veut la ressource
Grincheux veut la ressource
Dormeur veut la ressource
Prof veut la ressource
                Simplet relâche la ressource.
Simplet veut la ressource
        Simplet accède à la ressource.
                Simplet relâche la ressource.
Simplet veut la ressource
        Simplet accède à la ressource.
                Simplet relâche la ressource.
Simplet veut la ressource
        Simplet accède à la ressource.
                Simplet relâche la ressource.
Simplet veut la ressource
        Simplet accède à la ressource.
                Simplet relâche la ressource.
Simplet veut la ressource
        Simplet accède à la ressource.
*/
