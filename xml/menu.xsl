<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fo="http://www.w3.org/1999/XSL/Format">
  <xsl:output name="default" method="html" version="4.0" encoding="iso-8859-1" indent="yes"/>

    <xsl:template name="menu">
        <ul id="menu-deroulant">
            <li><a href="accueil.html">Page d'accueil</a></li><!--
            --><li><a href="#">Auteurs</a>
                <ul>
                    <xsl:for-each select="//auteur">
                        <li><a href="auteur_{@id}.html"><xsl:value-of select="idext"/></a></li>
                    </xsl:for-each>
                </ul>
            </li><!--
            --><li><a href="#">Recettes</a>
                <ul>
                    <xsl:for-each select="//recette">
                        <li><a href="recette_{@id}.html"><xsl:value-of select="nom"/></a></li>
                    </xsl:for-each>
                </ul>
            </li><!--
            --><li><a href="#">Ingrédients</a>
                <ul>
                    <xsl:for-each select="//ingredient">
                        <li><a href="ingredient_{@id}.html"><xsl:value-of select="nom"/></a></li>
                    </xsl:for-each>
                </ul>
            </li><!--
            --><li><a href="#">Catégories</a>
                <ul>
                    <xsl:for-each select="//categorie">
                        <li><a href="categorie_{@id}.html"><xsl:value-of select="nom"/></a></li>
                    </xsl:for-each>
                </ul>
            </li>
        </ul>
    </xsl:template>

</xsl:stylesheet>
