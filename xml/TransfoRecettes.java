import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.OutputKeys;
import javax.xml.transform.Source;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerConfigurationException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.w3c.dom.Text;

import java.io.File;
import java.net.URL;
import java.util.ArrayList;


/**
 * Permet d'afficher la liste brute des recettes ; d'afficher un arbre XML représentant toutes les recettes
 * ; d'afficher un arbre HTML contenant les recettes ; le tout sur la sortie standard
 * @author alexandre.leonardi@etu.univ-amu.fr
 * Utilisation : "java TransfoRecettes chemin/vers/fichier.xml"
 */
public class TransfoRecettes{
	public static void main(String[] args){
		try{
			if(args.length<1){
				throw new Exception("Vous devez passer le nom du fichier xml à parser en argument !");
			}
			
			TransfoRecettes transfo = new TransfoRecettes();
			
			//Affichage brut
			transfo.affichageRecettes(args);

			//Affichage arbre XML
			transfo.creationArbreDom(args);
			
			
		}catch(Exception e){e.printStackTrace();}
	}
	
	
	/**
	 * Part du type de noeud dont on veut extraire le contenu et remonte (récursivement) jusqu'à la racine
	 * en sauvegardant le nom des noeuds traversés
	 * Permet d'afficher les recettes sans connaître la structure du document XML à parser
	 * @param e l'élément courant dont on va tester la valeur du père avant de lancer l'appel récursif
	 * @param l la liste des noms des noeuds traversés
	 * @param rootName le nom de l'élément racine qui sert à arrêter la récursion
	 */
	private void botToTop(Element e, ArrayList<String> l, String rootName){
		if(!e.getNodeName().equals(rootName)){
			l.add(e.getNodeName());
			botToTop((Element) e.getParentNode(),l,rootName);
		}
		else{
			l.add(rootName);
		}
	}
	
	/**
	 * Copie une ArrayList de strings dans une autre
	 * @param src liste source
	 * @param destliste destination
	 * @throws Exception si jamais la liste source est vide
	 */
	private void copieAL(ArrayList<String> src, ArrayList<String> dest) throws Exception{
		if(src.isEmpty()){
			throw new Exception("Tentative de copier une liste vide.");
		}
		if(!dest.isEmpty()){
			dest.clear();
		}
		for(int i=0 ; i<src.size(); i++){
			dest.add(src.get(i));
		}
	}
	
	/**
	 * Part de la racine de l'arbre et recherche récursivement le chemin (i.e. la liste de noeuds à emprunter) pour
	 * arriver à un certain noeud cible
	 * @param e le noeud courant
	 * @param rootName le nom de la racine de l'arbre parcouru, utilisé pour l'appel à botToTop
	 * @param targetName le noeud du nom à atteindre, utilisé pour établir un cas terminal
	 * @param resultat la liste des noeuds à parcourir pour aller de root à target
	 */
	private void cheminVersRecette(Element e,String rootName, String targetName, ArrayList<String> resultat) throws Exception{ 
		NodeList nl = e.getChildNodes();
		for (int i=0;i<nl.getLength();i++){
			Node n=nl.item(i);
			if(n.getNodeName().equals(targetName)){
				ArrayList<String> l = new ArrayList<>();
				botToTop((Element)n,l,rootName);
				copieAL(l,resultat);
				return;
			}
			else if(n.getNodeType()==Node.ELEMENT_NODE){
				cheminVersRecette((Element)n,rootName,targetName,resultat);
			}
		}
	}
	
	/**
	 * Parcourt récursivement un arbre en ne s'autorisant à passer que par certain noeuds 
	 * et en ajoutant les noeuds empruntés à un Document 
	 * @param sousArbre le Document auquel sont concaténés les noeuds visités
	 * @param nodeNames la liste des noeuds que l'on peut emprunter
	 * @param courant le noeud courant, en lecture seul 
	 * @param parent le noeud créé à l'itération précédente, qui correspond au noeud courant de l'itération précédente
	 */
	private void topToBot(Document sousArbre, ArrayList<String> nodeNames,Element courant,Element parent){
		if(nodeNames.contains(courant.getNodeName())){
			Element tmp = sousArbre.createElement(courant.getNodeName());
			
			if(parent==null)sousArbre.appendChild(tmp);
			else parent.appendChild(tmp);
			
			NodeList nl = courant.getChildNodes();
			for(int i=0 ; i<nl.getLength() ; i++){
				Node n = nl.item(i);
				if(courant.getNodeName().equals(nodeNames.get(0)) && n.getNodeName().equals("nom")){
					Text text = sousArbre.createTextNode(n.getChildNodes().item(0).getNodeValue());
					tmp.appendChild(text);
				}
				else if(n.getNodeType()==Node.ELEMENT_NODE){
					topToBot(sousArbre,nodeNames,(Element)n,tmp);
				}
			}
		}
	}
	
	/**
	 * Parcourt un fichier XML pour créer en créer et afficher un sous-arbre
	 * @param args Arugments passés à l'exécution du programme ; doit contenir le nom du fichier XML en  position 0
	 * @throws Exception si le fichier XML spécifié n'existe pas
	 */
	private void creationArbreDom(String[] args) throws Exception{
		Document doc;
		DocumentBuilderFactory dbf=DocumentBuilderFactory.newInstance();
		DocumentBuilder db=dbf.newDocumentBuilder();
		
		Document sousArbre = DocumentBuilderFactory.newInstance().newDocumentBuilder().newDocument();
		
		File f = new File(args[0]);
		if(f.exists() && !f.isDirectory()) { 
			doc=db.parse(args[0]);
			Element root=doc.getDocumentElement();
			ArrayList<String> path = new ArrayList<>();
			
			//Changer "recette" pour une autre valeur pour afficher un sous-arbre différent
			//Il faut néanmoins que le noeud visé ait un enfant de type "nom" pour pouvoir afficher son nom 
			//(ex : le "idext" des auteurs n'est pas pris en charge)
			cheminVersRecette(root, root.getNodeName(),"recette",path);
			
			Element parent = sousArbre.getDocumentElement();
			topToBot(sousArbre,path,root,parent);
		}
		else{
			throw new Exception("Le fichier "+args[0]+" n'existe pas !");
		}
		
		TransformerFactory myFactory = TransformerFactory.newInstance();
		Transformer transformer = myFactory.newTransformer();
		transformer.setOutputProperty(OutputKeys.ENCODING, "iso-8859-1");
		transformer.setOutputProperty(OutputKeys.INDENT, "yes");
		transformer.transform(new DOMSource(sousArbre),new StreamResult(System.out));	
	}
	
	/**
	 * Parcourt un arbre XML et affiche la liste de ses "recettes"
	 * @param args Arugments passés à l'exécution du programme ; doit contenir le nom du fichier XML en  position 0
	 * @throws Exception Exception si le fichier XML spécifié n'existe pas
	 */
	private void affichageRecettes(String[] args) throws Exception{
		Document doc;
		DocumentBuilderFactory dbf=DocumentBuilderFactory.newInstance();
		DocumentBuilder db=dbf.newDocumentBuilder();

		//Si le fichier n'existe pas, message d'erreur
		File f = new File(args[0]);
		if(f.exists() && !f.isDirectory()) { 
			doc=db.parse(args[0]);
			Element root=doc.getDocumentElement();
			parcoursAffichageRecettes(root);
		}
		else{
			throw new Exception("Le fichier "+args[0]+" n'existe pas !");
		}
	}
	
	/**
	 * Implémentation récursive du parcours de l'arbre pour afficher ses "recettes"
	 * @param e le noeud courant
	 */
	private void parcoursAffichageRecettes(Element e){
		//Cas terminal
		if(e.getNodeName().equals("recette")){
			NodeList nl = e.getChildNodes();
			for (int i=0;i<nl.getLength();i++){
				Node n=nl.item(i);
				if(n.getNodeName().equals("nom")){
					System.out.println(n.getChildNodes().item(0).getNodeValue());
				}
			}
		}
		//Parcours des fils
		else{
			NodeList nl = e.getChildNodes();
			for (int i=0;i<nl.getLength();i++){
				Node n=nl.item(i);
				if(n.getNodeType()==Node.ELEMENT_NODE){
					parcoursAffichageRecettes((Element)n);
				}
			}
		}
	}

}
