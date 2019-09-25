script "atc_database"
/*************************ATC LIBRARY BASE DE DATO*************************************/
/*
Todo los comandos y funciones de la librería ATC que son para el trabajo con base de datos
tienen la forma identificado de librería _ db (Data base) _ Nombre del manipulador.
Ejemplo:
atc_db_GetDataOfTable

Esta librería está pensada para el desarrollo de app que usen más de una base de datos, aunque funciona 
en app de una sola base de datos.

PASOS PARA USAR LA FUNCIONALIDADES DE CONEXION A BASE DE DATOS
1. Configuramos la base de datos o la según sea el caso. Con el comando atc_db_SetupDataBase que usa los mismo
parámetros de revOpenDatabase con la diferencia que en el tipo de base de dato lleva un separador y un número.
Esto es importante porque si no se configura bien lo demás no funcionará correctamente.
Ejemplos:
atc_db_SetupDataBase "mysql-1", hostAddress, databaseName, [userName],[passWord],[useSSL], [socketAddr], [rwTimeout], [autoReconnect]
atc_db_SetupDataBase "odbc-5", hostAddress, databaseName, [userName],[passWord],[cursorType]
atc_db_SetupDataBase "sqlite_3",filePath,[sqliteOptions]
atc_db_SetupDataBase "postgresql", hostAddress, databaseName, [userName], [passWord] [, sslOption ...]
atc_db_SetupDataBase "oracle-5", hostAddress, databaseName, [userName],[passWord]
Como dije anteriormente es lo mismo que revOpenDatabase solo cambia el primer parámetro
por lo que se aconseja que consulte revOpenDatabase en la documentacion de LiveCode.

2. Consulta a base de datos
--Para realizar una consulta a una base de datos lo hacemos usando la funcion atc_db_DataFromQuery
que tiene como paremetros: 
-   1. Tipo de base de datos con uns separador valido (-, ., _ ) con el número de base de datos de este tipo
-   2. Una consultá SQL valida
-   3. El carácter que delimita las columnas por defecto TAB
-   4. El carácter que delimita las filas por defecto es RETURN
-   5. La decodificación de caracteres por defecto es UTF-8
-   6. Es una lista con una o más variable (o las expresiones que evalúan para los nombres de variable), separadas por comas.
-   7. Es un valor boleano, para indicar si la conexión con esta base de dato se cierra al finalizar la consulta . 
-      Este valor es verdadero por defecto por lo que al terminar la conexion se sierra automaticamete.
-     Al poner este parametro en falseo esta conexión estara abierta por un periodo de 30 segundos si se usa nuevamente el periodo de vida 
-     de esta conexión se amplia de lo contrario se cierra automaticamente.
Los nombres variables también pueden ser elementos de arreglos.
Ejemplo:
put atc_db_DataFromQuery ("sqlite-1","SELECT* FROM tabla") into tLocalDB
put atc_db_DataFromQuery ("MySQL-2","SELECT* FROM tabla","@", "|","UTF-16") into tInlineDB

Dejar claro que todo esto depende de que se configure de manera correcta atc_db_SetupDataBase.
3. Ejecutar código SQL en la base de datos
-- Para correr código SQL estándar en nuestras bases de datos usamos el comando atc_db_SetupDataBase
que tiene los parámetros:
-   1. Tipo de base de datos con un separador valido (- , . , _ ) con el número de base de datos de este tipo
-   2. Una sentencia SQL valida
-   3. La decodificación de caracteres por defecto es UTF-8
-   4. Es una lista con una o más variable (o las expresiones que evalúan para los nombres de variable), separadas por comas.
-   5.  Es un valor boleano, para indicar si la conexión con esta base de dato se cierra al finalizar la consulta . 
-      Este valor es verdadero por defecto por lo que al terminar la conexion se sierra automaticamete.
-     Al poner este parametro en falseo esta conexión estara abierta por un periodo de 30 segundos si se usa nuevamente el periodo de vida 
-     de esta conexión se amplia de lo contrario se cierra automaticamente.
Los nombres variables también pueden ser elementos de arreglos.
Ejemplo: 
atc_db_ExecuteSQL "sqlite-1","DELETE FROM ´nombre_tabla´ WHERE id is 15;","UTF-8"

Las demás funciones dependen de estas es decir que las funciones de esta librería usan atc_db_DataFromQuery y los comandos 
usan atc_db_ExecuteSQL
*/

--Toda la información de la base de datos a la que puedo acceder
local ATC_InfoOfAccedingToDataBase, sConnectOpen

command atc_db_SetupDataBase
   local tParameter
   --Guerdo el contenido de los parametros en un areglo para que no se pierdan al usar otras funciones
   repeat with x = 1 to paramCount()
      put param(x) into tParameter[x]
   end repeat
   
   -- El tipo de la base de dato, con un separador  y 
   -- el número que indica cual es dentro de las de su tipo.
   put token 1 of tParameter[1] into tTipo
   if not atc_db_AcceptedTypeDataBase(tTipo) then exit atc_db_SetupDataBase
   put token 3 of tParameter[1] into tNum
   if not isNumber(tNum) then put 1 into tNum
   --La dirección a la base de datos
   put tParameter[2] into ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["path"]
   
   if tTipo is "sqlite" then
      put tParameter[3] into ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["SqliteOptions"]
   else
      --El nombre de la base de datos
      put tParameter[3] into ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["DatabaseName"]
      -- Nombre de usuario
      put tParameter[4] into ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["UserName"]
      -- Es la contraseña
      put tParameter[5] into ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["Password"]
      
      switch tTipo
         case "mysql"
            put tParameter[6] into ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["useSSL"]
            put tParameter[7] into ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["socketAddr"]
            put tParameter[8] into ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["rwTimeout"]
            put tParameter[9] into ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["autoReconnect"]
            break
         case "odbc"
            put tParameter[6] into ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["cursorType"]
            break
         case "postgresql"
            put tParameter[6] into ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["sslOption "]
            break
      end switch
   end if
   
   //Los parámetros siguientes dependen del tipo de base de dato
   delete local tParameter
end atc_db_SetupDataBase

private function atc_db_OpenDataBase pTypeAndNum, pCloseAll
   local tTipo, tNum
   put token 1 of pTypeAndNum into tTipo
   put token 3 of pTypeAndNum into tNum
   if  not isNumber(tNum) then put 1 into tNum
   if pCloseAll is not false then   atc_db_ClosingConnectionsDataBase
   
   //validando campos obligatorios
   if ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["path"] is "" then
      exit atc_db_OpenDataBase
   else      
      if ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["DatabaseName"]  is "" and tTipo is not  "sqlite" then
         exit atc_db_OpenDataBase
      end if
   end if
   
   switch tTipo
      case "mysql"     
         return revOpenDatabase("mysql",\
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["path"], \
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["DatabaseName"],  \
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["UserName"], \
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["Password"], \
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["useSSL"],\
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["socketAddr"],\
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["rwTimeout"],\
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["autoReconnect"])
         break         
      case "odbc"
         return  revOpenDatabase("odbc",\
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["path"], \
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["DatabaseName"],  \
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["UserName"], \
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["Password"], \
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["cursorType"])
         break
      case "sqlite"
         return revOpenDatabase("sqlite",\
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["path"], \
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["sqliteOptions"])
         break
      case"postgresql"
         return revOpenDatabase("postgresql",\
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["path"], \
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["DatabaseName"],  \
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["UserName"], \
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["Password"], \
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["sslOption "])
         break
      case"oracle"
         return revOpenDatabase("oracle",\
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["path"], \
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["DatabaseName"],  \
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["UserName"], \
               ATC_InfoOfAccedingToDataBase[tTipo][ tNum]["Password"]) 
         break
   end switch
end atc_db_OpenDataBase

private function atc_db_AcceptedTypeDataBase pTypeDB
   if pTypeDB is among the items of "mysql,odbc,sqlite,postgresql,oracle" then
      return true
   else
      beep 
      answer error "ATC ERROR: Las base de datos del tipo ("&pTypeDB&\
            ") no es soportadas. Use una del tipo mysql, odbc, sqlite, postgresql o oracle. "
      return false
   end if
end atc_db_AcceptedTypeDataBase

private command atc_db_ClosingConnectionsDataBase
   if isNumber(ATC_CurrentDatabaseID) then revCloseDatabase sATC_CurrentDatabaseID
   put revOpenDatabases() into tListOpenOP
   --Conexiones que no quiero que se ronpan por ahora
   local i = 1
   repeat for each key idDataBasr in sConnectOpen
      put item 2 of sConnectOpen[idDataBasr] into line i of tListID
      add 1 to i
   end repeat
   -- Matando todas las conexiones menos las que estan en la lista de tListID
   repeat for each item tID in tListOpenOP
      if tID is among the lines of tListID  then next repeat
      revCloseDatabase tID
   end repeat
end atc_db_ClosingConnectionsDataBase
 
function atc_db_DataFromQuery pType, pSQL, pColumnDelim, pRowDelim,pTextDecode, pVarsList, pCloseConnect
   if pCloseConnect is not false then put true into pCloseConnect
   put item 2 of  sConnectOpen[pType] into tID
   if tID is empty then
      put atc_db_OpenDataBase (pType,pCloseConnect) into tID
   else
      put  the millisec,tID into sConnectOpen[pType]
   end if
   
   if  not isNumber(tID) then return tID
   
   local tTipo, tNum
   put token 1 of pType into tTipo
   put token 3 of pType into tNum
   if  not isNumber(tNum) then
      put 1 into tNum
      put tTipo &"-"& tNum into pType
   end if
   if pTextDecode is empty then put "UTF-8" into pTextDecode
   --Si los delimitadores son vacío los llenos con los pordefectos
   if pColumnDelim is empty then put tab into pColumnDelim
   if pRowDelim is empty then put return into pRowDelim
   put revDataFromQuery(pColumnDelim,pRowDelim,tID,pSQL,pVarsList) into tResult
   --Si cierro la conexión al terminar la cosulta o la dejo abierta para realizar otra consulta a esta base de datos
   if pCloseConnect then
      atc_db_ClosingConnectionsDataBase
   else
      put  the millisec,tID into sConnectOpen[pType]
      send "atc_db_ClosesConnectOpen pType" to stack "atc_library" in 5 sec
   end if
   return textDecode (tResult, pTextDecode)
end atc_db_DataFromQuery

command atc_db_ExecuteSQL pType, pSQL,pTextDecode, pVariablesOrArray, pCloseConnect
   if pCloseConnect is not false then put true into pCloseConnect
   put item 2 of sConnectOpen[pType] into tID
   if tID is empty then
      put atc_db_OpenDataBase (pType,pCloseConnect) into tID
   else
      put  the millisec,tID into sConnectOpen[pType]
   end if
   
   local tTipo, tNum
   put token 1 of pType into tTipo
   put token 3 of pType into tNum
   if  not isNumber(tNum) then
      put 1 into tNum
      put tTipo &"-"& tNum into pType
   end if
   if pTextDecode is empty then put "UTF-8" into pTextDecode
   put textEncode (pSQL, pTextDecode) into pSQL
   
   if  not isNumber(tID) then return tID
   revExecuteSQL tID, pSQL, pVariablesOrArray
   --Si cierro la conexión al terminar la cosulta o la dejo abierta para realizar otra consulta a esta base de datos
   if pCloseConnect then
      atc_db_ClosingConnectionsDataBase
   else
      put  the millisec,tID into sConnectOpen[pType]
      send "atc_db_ClosesConnectOpen pType" to me in 5 sec
   end if
end atc_db_ExecuteSQL
//Este comando es para uso interno de la librería ATC
command atc_db_ClosesConnectOpen pIdDataBase
   if the millisec - item 1 of sConnectOpen[pIdDataBase] >= 5000  then 
      revCloseDatabase item 2 of sConnectOpen[pIdDataBase]
      delete local sConnectOpen[pIdDataBase]
   end if
end atc_db_ClosesConnectOpen
