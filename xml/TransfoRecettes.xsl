<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fo="http://www.w3.org/1999/XSL/Format">
  <xsl:output name="defaut" method="html" version="4.0" encoding="iso-8859-1" indent="yes"/>

  <xsl:template match="root">
    <html>
      <head>
      </head>
      <body>
	<xsl:for-each select="*">
	  <xsl:value-of select="local-name()"/>
	</xsl:for-each>
      </body>	
    </html>
  </xsl:template>

</xsl:stylesheet>
