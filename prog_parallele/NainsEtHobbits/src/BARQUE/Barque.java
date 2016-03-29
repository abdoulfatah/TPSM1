// -*- coding: utf-8 -*-

package BARQUE;

import java.util.ArrayList;
import java.util.LinkedList;
import java.util.Random;

public class Barque{
	public enum Berge { NORD, SUD }
	final static int nbNainsAuNord = 6;
	final static int nbHobbitsAuNord = 0;
	final static int nbNainsAuSud = 4;
	final static int nbHobbitsAuSud = 0;
	private volatile Berge bergeActuelle;//Sauvegarde de quel côté on se trouve
	private volatile ArrayList<Thread> passagers = new ArrayList<>();
	private volatile boolean traversee = false;
	
	public static void main(String[] args){
		Barque laBarque = new Barque();
		new Passeur(laBarque);
		for(int i=0; i<nbNainsAuNord; i++) new Nain(laBarque,Berge.NORD).setName("NN-"+i);
		for(int i=0; i<nbHobbitsAuNord; i++) new Hobbit(laBarque,Berge.NORD).setName("HN-"+i);
		for(int i=0; i<nbNainsAuSud; i++) new Nain(laBarque,Berge.SUD).setName("NS-"+i);
		for(int i=0; i<nbHobbitsAuSud; i++) new Hobbit(laBarque,Berge.SUD).setName("HS-"+i);
	}

	private Berge inverse(Berge b){
		Berge ret;
		if(b==Berge.NORD) ret = Berge.SUD;
		else ret = Berge.NORD;
		return ret;
	}
	

	/* Code associé au passeur */
	public synchronized void accosterLaBerge(Berge berge) throws Exception{
		if(berge == bergeActuelle) throw new Exception("Vous essayez d'accoster sur une berge où vous vous trouvez déjà !");
		bergeActuelle = berge;
		System.out.println("PASSEUR> La barque accoste au "+ bergeActuelle +".");
	}
	
	public synchronized void charger(){
		while(passagers.size()!=4 || traversee){
			try{wait();}
			catch(InterruptedException e){e.printStackTrace();}
		}
		
		System.out.println("Je rame vers le "+inverse(bergeActuelle)+".");
		System.out.println(passagers);
		traversee = true;
		notifyAll();
	}
	
	public synchronized void decharger(){
		while(passagers.size()!=0 || !traversee){
			try{wait();}
			catch(InterruptedException e){e.printStackTrace();}
		}
		
		System.out.println("Arrivée au "+bergeActuelle);
		notifyAll();
		traversee=false;
	}

	/* Code associé aux nains */
	public synchronized void embarquerUnNain(Berge origine){
		while(!(bergeActuelle==origine) || passagers.size()>=4){
			try{wait();}
			catch(InterruptedException e){e.printStackTrace();}
		}
		
		passagers.add(Thread.currentThread());
		System.out.println("\t"+Thread.currentThread().getName()+"> J'embarque pour le "+inverse(origine)+".");
		notifyAll();
	}
	public synchronized void debarquerUnNain(Berge origine){
		while(!(bergeActuelle==inverse(origine)) || !traversee){
			try{wait();}
			catch(InterruptedException e){e.printStackTrace();}
		}
		
		System.out.println("\t"+Thread.currentThread().getName()+"> Je débarque au "+inverse(origine)+".");
		passagers.remove(Thread.currentThread());
	}
	
	/* Code associé aux hobbits */
	public synchronized void embarquerUnHobbit(Berge origine){}
	public synchronized void debarquerUnHobbit(Berge origine){}
}    


class Passeur extends Thread{
	public Barque laBarque;
	public Passeur(Barque b){
		this.laBarque = b;
		start();
	}
	public void run(){
		try{
			laBarque.accosterLaBerge(Barque.Berge.NORD);
			while(true){
				laBarque.charger();
				sleep(1000);
				laBarque.accosterLaBerge(Barque.Berge.SUD);
				laBarque.decharger();
				laBarque.charger();
				sleep(1000);
				laBarque.accosterLaBerge(Barque.Berge.NORD);
				laBarque.decharger();
			}
		}
		catch(Exception e){e.printStackTrace();}	
	}
}



class Nain extends Thread{
	public Barque laBarque;
	public Barque.Berge origine;
	public Nain(Barque b, Barque.Berge l){
		this.laBarque = b;
		this.origine = l;
		start();
	}
	public void run(){
		Random alea = new Random();
		try {sleep(500+alea.nextInt(100)*50);}
		catch (InterruptedException e) {e.printStackTrace();}
		System.out.println(Thread.currentThread().getName()+
				"> Je souhaite traverser.");
		laBarque.embarquerUnNain(origine);
		laBarque.debarquerUnNain(origine);
	}
}	

class Hobbit extends Thread{
	public Barque laBarque;
	public Barque.Berge origine;
	public Hobbit(Barque b, Barque.Berge l){
		this.laBarque = b;
		this.origine = l;
		start();
	}
	public void run(){
		Random alea = new Random();
		try {sleep(500+alea.nextInt(100)*50);}
		catch (InterruptedException e) {e.printStackTrace();}
		System.out.println(Thread.currentThread().getName()+
				"> Je souhaite traverser.");
		laBarque.embarquerUnHobbit(origine);
		laBarque.debarquerUnHobbit(origine);
	}
}	

