<?xml version="1.0" encoding="ISO-8859"?>
<!--xmlns:fo="http://www.w3.org/1999/XSL/Format"-->
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output
      method="xml"
      doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
      doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"
      indent="yes"
      encoding="iso-8859-1"
      />
  <!--#######################################################
      #       Transformation des recettes brutes            #
      #         en une version formatée pour                #
      #          correspondre à recettes.dtd                #
      ####################################################### -->

  <xsl:strip-space elements="*"/>
  
  <!-- Template matchant la racine, et qui appelle tous les autres -->
  <xsl:template match="/">
    <root>
      <xsl:apply-templates/>
    </root>
  </xsl:template>

  <!-- ======================================================== -->
  <!-- Templates représentant, dans l'ordre, la liste des recette, des ingrédients, des auteurs et des catégories -->

  <xsl:template  match="objets">
    <liste_recettes>
      <xsl:for-each select="//objet[@type='recette']">
	<recette id="{@id}">
	  <xsl:call-template name="commun"/>
	</recette>
      </xsl:for-each>
    </liste_recettes>
    <liste_ingredients>
      <xsl:for-each select="//objet[@type='ingredient']">
	<ingredient id="{@id}">
	  <xsl:call-template name="commun"/>
	</ingredient>
      </xsl:for-each>
    </liste_ingredients>
    <liste_auteurs>
      <xsl:for-each select="//objet[@type='auteur']">
	<auteur id="{@id}">
	  <xsl:call-template name="commun"/>
	</auteur>
      </xsl:for-each>
    </liste_auteurs>
    <liste_categories>
      <xsl:for-each select="//objet[@type='catégorie']">
	<categorie id="{@id}">
	  <xsl:call-template name="commun"/>
	  <xsl:call-template name="sous-catégories">
	    <xsl:with-param name="parent_id" select="@id"/>
	  </xsl:call-template>
	</categorie>
      </xsl:for-each>
    </liste_categories>
  </xsl:template>

  <xsl:template name="commun">
    <xsl:for-each select="info">
      <xsl:element name="{@nom}"><xsl:value-of select="@value"/><xsl:text/><xsl:value-of select="."/><xsl:text/></xsl:element>
    </xsl:for-each>
  </xsl:template>

  <xsl:template name="sous-catégories">
    <xsl:param name="parent_id"/>
    <xsl:for-each select="//objet[@type='sous-catégorie']">
      <xsl:if test="info[@nom='nom_categorie' and @value=$parent_id]">
	<sous-categorie id="{@id}">
	  <xsl:call-template name="commun"/>
	</sous-categorie>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>
