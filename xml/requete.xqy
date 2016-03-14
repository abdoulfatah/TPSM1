xquery version "3.0" encoding "utf-8";
declare option saxon:output "method=xhtml";
declare option saxon:output "doctype-public=-//W3C//DTD XHTML 1.0 Strict//EN";
declare option saxon:output "doctype-system=http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd";
declare option saxon:output "omit-xml-declaration=no";
declare option saxon:output "indent=yes";

(: Logiciel utilisé : saxon home edition 9.7 for Java :)
(:http://saxon.sourceforge.net/#F9.7HE:)
(: Commande utilisée : :)
(: java -cp SaxonHE9-7-0-3J/saxon9he.jar net.sf.saxon.Query -q:requete.xqy -o:qry_result.html:)

declare function local:liste_recettes($id_auteur as xs:string)
{
	for $recette in doc("recettes.xml")//recette[nom_auteur=$id_auteur] order by $recette/nom return
        <ul>
            <li>
                {$recette/nom}
                :
                {for $sc in doc("recettes.xml")//sous-categorie[@id=$recette/nom_sous-categorie]
                    return $sc/nom}
            </li>
        </ul>
};
let $doc := doc("recettes.xml") return
<html>
  <head>
    <title>XQuery</title>
  </head>
  <body>
    <ul>
      {for $auteur in $doc//auteur order by $auteur/idext  return
      <li>
	<b>{ $auteur/idext} :</b> {local:liste_recettes($auteur/@id)}
      </li>}
    </ul>
  </body>
</html>