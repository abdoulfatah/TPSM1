// -*- coding: utf-8 -*-

import java.util.*;

public class Main {
    public static void main(String args[]) {
	int siegeNb = 0, clientNb = 0;
	try { siegeNb  = Integer.parseInt(args[0]); clientNb = Integer.parseInt(args[1]); }
	catch(Exception e) {
	    System.err.println("Usage: barbier <sieges> <clients>"); System.exit(1);
	}
	System.out.println(siegeNb + " sièges, " + clientNb + " clients");
	Salon salon = new Salon(siegeNb);
	Barbier barbier = new Barbier(salon); barbier.start();
	for (int i = 0; i < clientNb; i++) { new Client("C"+i, salon).start(); }
    }
}  

public class Barbier extends Thread {
    private Salon salon;
    private Client client;
    public Barbier(Salon salon) {
        this.salon = salon;
        this.client = null;
    }
    public void run() {
        System.out.println("B: Le salon est ouvert !");
        while (true) {
	    salon.suivant();
	    System.out.println("B: Le fauteuil est vide: au prochain!");
        }
    }
}

public class Client extends Thread {
    private static Random alea = new Random();
    private Salon salon;
    private int pousse = 0;
    public Client(String name, Salon salon) {
        this.salon = salon;
        setName(name);
        pousse = (alea.nextInt(8) + 3);
    }
    public void run() {
        while (true) {
	    System.out.println(getName() + ": Ma barbe sera trop longue dans " +pousse+ " s");
	    try { sleep(pousse * 1000); } catch (InterruptedException ie) {}
	    while (!salon.seFaireRaser()) {
		System.out.println(getName() + ": Il y a trop de monde!");
		try { sleep(pousse * 500); } catch (InterruptedException ie) {}
	    }
	    System.out.println(getName() + ": Je quitte le salon.");
        }
    }
}

public class Salon {
    private Queue<Client> file; // Le salon utilise une file de clients
    private int sieges;
    public Salon(int sieges) {
	this.sieges = sieges;
	file = new LinkedList<Client>();
    }
    public synchronized boolean seFaireRaser() { ... }
    public synchronized Client suivant() { ... }
}

