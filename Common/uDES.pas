unit uDES;

interface

uses
   Windows, Classes, SysUtils;

type
   fdArray   = array of dword;

   function EncryStr(Str, Key: String): String;overload;
   function EncryStr(Str:TStream; Key: String): String;overload;
   function DecryStr(Str, Key: String): String;overload;
   function DecryStr(Str:TStream; Key: String): String;overload;
   function EncryStrHex(Str, Key: String): String;
   function DecryStrHex(Str, Key: String): String;overload;
   function DecryStrHex(Str:TStream; Key: String): String;overload;

   function des(key:string;smessage:string;encrypt:dword;mode:dword;iv:string):string;
   function des_createKeys(key:string):fdArray;
   function StrToHex(Str:string):string;
   function HexToStr(Hex:string):string;
   function IsInt(Str:String):Boolean;

implementation

function EncryStr(Str, Key: String): String;
begin
   Result := des(Key, Str, 1, 0, '');
end;

function EncryStr(Str:TStream; Key: String): String;
var
   AStr:String;
begin
   Str.Seek(0,soFromBeginning);
   setlength(AStr, Str.Size);
   Str.Read(AStr[1], Str.Size);
   Result := des(Key, AStr, 1, 0, '');
end;

function DecryStr(Str, Key: String): String;
begin
   Result := trim(des(Key, Str, 0, 0, ''));
end;

function DecryStr(Str:TStream; Key: String): String;
var
   AStr:String;
begin
   Str.Seek(0,soFromBeginning);
   setlength(AStr, Str.Size);
   Str.Read(AStr[1], Str.Size);
   Result := trim(des(Key, AStr, 0, 0, ''));
end;

function EncryStrHex(Str, Key: String): String;
begin
   Result := trim(StrToHex(des(Key, Str, 1, 0, '')));
end;

function DecryStrHex(Str, Key: String): String;
begin
   Result := trim(des(Key, HexToStr(Str), 0, 0, ''));
end;

function DecryStrHex(Str:TStream; Key: String): String;
var
   AStr:String;
begin
   Str.Seek(0,soFromBeginning);
   setlength(AStr, Str.Size);
   Str.Read(AStr[1], Str.Size);
   Result := trim(des(Key, HexToStr(AStr), 0, 0, ''));
end;

function des(key:string;smessage:string;encrypt:dword;mode:dword;iv:string):string;
const
   spfunction1 : array[0..63] of dword = ($1010400,0,$10000,$1010404,$1010004,$10404,$4,$10000,$400,$1010400,$1010404,$400,$1000404,$1010004,$1000000,$4,$404,$1000400,$1000400,$10400,$10400,$1010000,$1010000,$1000404,$10004,$1000004,$1000004,$10004,0,$404,$10404,$1000000,$10000,$1010404,$4,$1010000,$1010400,$1000000,$1000000,$400,$1010004,$10000,$10400,$1000004,$400,$4,$1000404,$10404,$1010404,$10004,$1010000,$1000404,$1000004,$404,$10404,$1010400,$404,$1000400,$1000400,0,$10004,$10400,0,$1010004);
   spfunction2 : array[0..63] of dword = ($80108020,$80008000,$8000,$108020,$100000,$20,$80100020,$80008020,$80000020,$80108020,$80108000,$80000000,$80008000,$100000,$20,$80100020,$108000,$100020,$80008020,0,$80000000,$8000,$108020,$80100000,$100020,$80000020,0,$108000,$8020,$80108000,$80100000,$8020,0,$108020,$80100020,$100000,$80008020,$80100000,$80108000,$8000,$80100000,$80008000,$20,$80108020,$108020,$20,$8000,$80000000,$8020,$80108000,$100000,$80000020,$100020,$80008020,$80000020,$100020,$108000,0,$80008000,$8020,$80000000,$80100020,$80108020,$108000);
   spfunction3 : array[0..63] of dword = ($208,$8020200,0,$8020008,$8000200,0,$20208,$8000200,$20008,$8000008,$8000008,$20000,$8020208,$20008,$8020000,$208,$8000000,$8,$8020200,$200,$20200,$8020000,$8020008,$20208,$8000208,$20200,$20000,$8000208,$8,$8020208,$200,$8000000,$8020200,$8000000,$20008,$208,$20000,$8020200,$8000200,0,$200,$20008,$8020208,$8000200,$8000008,$200,0,$8020008,$8000208,$20000,$8000000,$8020208,$8,$20208,$20200,$8000008,$8020000,$8000208,$208,$8020000,$20208,$8,$8020008,$20200);
   spfunction4 : array[0..63] of dword = ($802001,$2081,$2081,$80,$802080,$800081,$800001,$2001,0,$802000,$802000,$802081,$81,0,$800080,$800001,$1,$2000,$800000,$802001,$80,$800000,$2001,$2080,$800081,$1,$2080,$800080,$2000,$802080,$802081,$81,$800080,$800001,$802000,$802081,$81,0,0,$802000,$2080,$800080,$800081,$1,$802001,$2081,$2081,$80,$802081,$81,$1,$2000,$800001,$2001,$802080,$800081,$2001,$2080,$800000,$802001,$80,$800000,$2000,$802080);
   spfunction5 : array[0..63] of dword = ($100,$2080100,$2080000,$42000100,$80000,$100,$40000000,$2080000,$40080100,$80000,$2000100,$40080100,$42000100,$42080000,$80100,$40000000,$2000000,$40080000,$40080000,0,$40000100,$42080100,$42080100,$2000100,$42080000,$40000100,0,$42000000,$2080100,$2000000,$42000000,$80100,$80000,$42000100,$100,$2000000,$40000000,$2080000,$42000100,$40080100,$2000100,$40000000,$42080000,$2080100,$40080100,$100,$2000000,$42080000,$42080100,$80100,$42000000,$42080100,$2080000,0,$40080000,$42000000,$80100,$2000100,$40000100,$80000,0,$40080000,$2080100,$40000100);
   spfunction6 : array[0..63] of dword = ($20000010,$20400000,$4000,$20404010,$20400000,$10,$20404010,$400000,$20004000,$404010,$400000,$20000010,$400010,$20004000,$20000000,$4010,0,$400010,$20004010,$4000,$404000,$20004010,$10,$20400010,$20400010,0,$404010,$20404000,$4010,$404000,$20404000,$20000000,$20004000,$10,$20400010,$404000,$20404010,$400000,$4010,$20000010,$400000,$20004000,$20000000,$4010,$20000010,$20404010,$404000,$20400000,$404010,$20404000,0,$20400010,$10,$4000,$20400000,$404010,$4000,$400010,$20004010,0,$20404000,$20000000,$400010,$20004010);
   spfunction7 : array[0..63] of dword = ($200000,$4200002,$4000802,0,$800,$4000802,$200802,$4200800,$4200802,$200000,0,$4000002,$2,$4000000,$4200002,$802,$4000800,$200802,$200002,$4000800,$4000002,$4200000,$4200800,$200002,$4200000,$800,$802,$4200802,$200800,$2,$4000000,$200800,$4000000,$200800,$200000,$4000802,$4000802,$4200002,$4200002,$2,$200002,$4000000,$4000800,$200000,$4200800,$802,$200802,$4200800,$802,$4000002,$4200802,$4200000,$200800,0,$2,$4200802,0,$200802,$4200000,$800,$4000002,$4000800,$800,$200002);
   spfunction8 : array[0..63] of dword = ($10001040,$1000,$40000,$10041040,$10000000,$10001040,$40,$10000000,$40040,$10040000,$10041040,$41000,$10041000,$41040,$1000,$40,$10040000,$10000040,$10001000,$1040,$41000,$40040,$10040040,$10041000,$1040,0,0,$10040040,$10000040,$10001000,$41040,$40000,$41040,$40000,$10041000,$1000,$40,$10040040,$1000,$41040,$10001000,$40,$10000040,$10040000,$10040040,$10000000,$40000,$10001040,0,$10041040,$40040,$10000040,$10040000,$10001000,$10001040,0,$10041040,$41000,$41000,$1040,$1040,$40040,$10000000,$10041000);
var
   keys:fdArray;
   m, i, j:integer;
   temp, temp2, right1, right2, left, right:dword;
   looping:array of integer;
   cbcleft, cbcleft2, cbcright, cbcright2:dword;
   endloop, loopinc:integer;
   len, iterations:integer;
   chunk:integer;
   tempresult:string;
begin
   //create the 16 or 48 subkeys we will need
   keys := des_createKeys(key);
   m:=0;cbcleft:=0;cbcleft2:=0;cbcright:=0;cbcright2:=0;chunk:=0;
   len := length(smessage);
   //set up the loops for single and triple des
   if length(keys) = 32 then
     iterations := 3
   else
     iterations := 9;

   if iterations = 3 then
     begin
       if encrypt = 1 then
         begin
           setlength(looping,3);
           looping[0] := 0;
           looping[1] := 32;
           looping[2] := 2;
         end
       else
         begin
           setlength(looping,3);
           looping[0] := 30;
           looping[1] := -2;
           looping[2] := -2;
         end;
     end
   else
     begin
       if encrypt = 1 then
         begin
           setlength(looping,9);
           looping[0] := 0;
           looping[1] := 32;
           looping[2] := 2;
           looping[3] := 62;
           looping[4] := 30;
           looping[5] := -2;
           looping[6] := 64;
           looping[7] := 96;
           looping[8] := 2;
         end
       else
         begin
           setlength(looping,9);
           looping[0] := 94;
           looping[1] := 62;
           looping[2] := -2;
           looping[3] := 32;
           looping[4] := 64;
           looping[5] := 2;
           looping[6] := 30;
           looping[7] := -2;
           looping[8] := -2;
         end;
     end;

   smessage := smessage + #0#0#0#0#0#0#0#0; //pad the message out with null bytes

   //store the result here
   result := '';
   tempresult := '';

   if mode = 1 then //CBC mode
     begin
       cbcleft := (ord(iv[m+1]) shl 24) or (ord(iv[m+2]) shl 16) or (ord(iv[m+3]) shl 8) or ord(iv[m+4]);
       cbcright := (ord(iv[m+5]) shl 24) or (ord(iv[m+6]) shl 16) or (ord(iv[m+7]) shl 8) or ord(iv[m+8]);
       m:=0;
     end;

   //loop through each 64 bit chunk of the message
   while m < len do
     begin
       left := (ord(smessage[m+1]) shl 24) or (ord(smessage[m+2]) shl 16) or (ord(smessage[m+3]) shl 8) or ord(smessage[m+4]);
       right := (ord(smessage[m+5]) shl 24) or (ord(smessage[m+6]) shl 16) or (ord(smessage[m+7]) shl 8) or ord(smessage[m+8]);
       m := m + 8;

       //for Cipher Block Chaining mode, xor the message with the previous result
       if mode = 1 then
         if encrypt=1 then
           begin
             left := left xor cbcleft;
             right := right xor cbcright;
           end
         else
           begin
             cbcleft2 := cbcleft;
             cbcright2 := cbcright;
             cbcleft := left;
             cbcright := right;
           end;

       //first each 64 but chunk of the message must be permuted according to IP
       temp := ((left shr 4) xor right) and $0f0f0f0f; right := right xor temp; left := left xor (temp shl 4);
       temp := ((left shr 16) xor right) and $0000ffff; right := right xor temp; left := left xor (temp shl 16);
       temp := ((right shr 2) xor left) and $33333333; left := left xor temp; right := right xor (temp shl 2);
       temp := ((right shr 8) xor left) and $00ff00ff; left := left xor temp; right := right xor (temp shl 8);
       temp := ((left shr 1) xor right) and $55555555; right := right xor temp; left := left xor (temp shl 1);

       left := ((left shl 1) or (left shr 31));
       right := ((right shl 1) or (right shr 31));

       //do this either 1 or 3 times for each chunk of the message
       j:=0;
       while j<iterations do
         begin
           endloop := looping[j+1];
           loopinc := looping[j+2];
           //now go through and perform the encryption or decryption
           i:= looping[j];
           while i<>endloop do
             begin
               right1 := right xor keys[i];
               right2 := ((right shr 4) or (right shl 28)) xor keys[i+1];
               //the result is attained by passing these bytes through the S selection functions
               temp := left;
               left := right;
               right := temp xor (spfunction2[(right1 shr 24) and $3f] or spfunction4[(right1 shr 16) and $3f]
                        or spfunction6[(right1 shr   8) and $3f] or spfunction8[right1 and $3f]
                        or spfunction1[(right2 shr 24) and $3f] or spfunction3[(right2 shr 16) and $3f]
                        or spfunction5[(right2 shr   8) and $3f] or spfunction7[right2 and $3f]);
               i:=i+loopinc;
             end;
           temp := left; left := right; right := temp; //unreverse left and right
           j:=j+3;
         end; //for either 1 or 3 iterations

       //move then each one bit to the right
       left := ((left shr 1) or (left shl 31));
       right := ((right shr 1) or (right shl 31));

       //now perform IP-1, which is IP in the opposite direction
       temp := ((left shr 1) xor right) and $55555555; right := right xor temp; left :=left xor (temp shl 1);
       temp := ((right shr 8) xor left) and $00ff00ff; left := left xor temp; right := right xor (temp shl 8);
       temp := ((right shr 2) xor left) and $33333333; left := left xor temp; right := right xor (temp shl 2);
       temp := ((left shr 16) xor right) and $0000ffff; right := right xor temp; left := left xor (temp shl 16);
       temp := ((left shr 4) xor right) and $0f0f0f0f; right := right xor temp; left := left xor (temp shl 4);

       //for Cipher Block Chaining mode, xor the message with the previous result
       if mode = 1 then
         if encrypt=1 then
           begin
           cbcleft := left; cbcright := right;
           end
         else
           begin
             left :=left xor cbcleft2;
             right := right xor cbcright2;
           end;

       tempresult := tempresult + chr(left shr 24) + chr((left shr 16) and $ff) + chr((left shr 8) and $ff) + chr(left and $ff) + chr(right shr 24) + chr((right shr 16) and $ff) + chr((right shr 8) and $ff) + chr(right and $ff);

       chunk := chunk + 8;
       if chunk = 512 then
         begin
           result := result + tempresult; tempresult := ''; chunk := 0;
         end;
     end; //for every 8 characters, or 64 bits in the message

   //return the result as an array
   result := result + tempresult;
end; //end of des

//des_createKeys
//this takes as input a 64 bit key (even though only 56 bits are used)
//as an array of 2 dwords, and returns 16 48 bit keys
function des_createKeys(key:string):fdArray;
const
   //declaring this locally speeds things up a bit
   pc2bytes0   :array[0..15] of dword= (0,$4,$20000000,$20000004,$10000,$10004,$20010000,$20010004,$200,$204,$20000200,$20000204,$10200,$10204,$20010200,$20010204);
   pc2bytes1   :array[0..15] of dword= (0,$1,$100000,$100001,$4000000,$4000001,$4100000,$4100001,$100,$101,$100100,$100101,$4000100,$4000101,$4100100,$4100101);
   pc2bytes2   :array[0..15] of dword= (0,$8,$800,$808,$1000000,$1000008,$1000800,$1000808,0,$8,$800,$808,$1000000,$1000008,$1000800,$1000808);
   pc2bytes3   :array[0..15] of dword= (0,$200000,$8000000,$8200000,$2000,$202000,$8002000,$8202000,$20000,$220000,$8020000,$8220000,$22000,$222000,$8022000,$8222000);
   pc2bytes4   :array[0..15] of dword= (0,$40000,$10,$40010,0,$40000,$10,$40010,$1000,$41000,$1010,$41010,$1000,$41000,$1010,$41010);
   pc2bytes5   :array[0..15] of dword= (0,$400,$20,$420,0,$400,$20,$420,$2000000,$2000400,$2000020,$2000420,$2000000,$2000400,$2000020,$2000420);
   pc2bytes6   :array[0..15] of dword= (0,$10000000,$80000,$10080000,$2,$10000002,$80002,$10080002,0,$10000000,$80000,$10080000,$2,$10000002,$80002,$10080002);
   pc2bytes7   :array[0..15] of dword= (0,$10000,$800,$10800,$20000000,$20010000,$20000800,$20010800,$20000,$30000,$20800,$30800,$20020000,$20030000,$20020800,$20030800);
   pc2bytes8   :array[0..15] of dword= (0,$40000,0,$40000,$2,$40002,$2,$40002,$2000000,$2040000,$2000000,$2040000,$2000002,$2040002,$2000002,$2040002);
   pc2bytes9   :array[0..15] of dword= (0,$10000000,$8,$10000008,0,$10000000,$8,$10000008,$400,$10000400,$408,$10000408,$400,$10000400,$408,$10000408);
   pc2bytes10 :array[0..15] of dword= (0,$20,0,$20,$100000,$100020,$100000,$100020,$2000,$2020,$2000,$2020,$102000,$102020,$102000,$102020);
   pc2bytes11 :array[0..15] of dword= (0,$1000000,$200,$1000200,$200000,$1200000,$200200,$1200200,$4000000,$5000000,$4000200,$5000200,$4200000,$5200000,$4200200,$5200200);
   pc2bytes12 :array[0..15] of dword= (0,$1000,$8000000,$8001000,$80000,$81000,$8080000,$8081000,$10,$1010,$8000010,$8001010,$80010,$81010,$8080010,$8081010);
   pc2bytes13 :array[0..15] of dword= (0,$4,$100,$104,0,$4,$100,$104,$1,$5,$101,$105,$1,$5,$101,$105);

   //now define the left shifts which need to be done
   shifts :array[0..15] of dword = (0, 0, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0);
var
   iterations:integer;
   keys:fdArray;
   lefttemp, righttemp, temp:dword;
   m, n, j,i:integer;
   left,right:dword;
begin
   //how many iterations (1 for des, 3 for triple des)
   if length(key) = 24 then
     iterations := 3
   else
     iterations := 1;

   //stores the return keys
   setlength(keys,32 * iterations);

   //other variables
   m:=0;n:=0;

   for j:=0 to iterations-1 do //either 1 or 3 iterations
     begin
       left := (ord(key[m+1]) shl 24) or (ord(key[m+2]) shl 16) or (ord(key[m+3]) shl 8) or ord(key[m+4]);
       right := (ord(key[m+5]) shl 24) or (ord(key[m+6]) shl 16) or (ord(key[m+7]) shl 8) or ord(key[m+8]);
       m:=m+8;

       temp := ((left shr 4) xor right) and $0f0f0f0f; right :=right xor temp; left :=left xor (temp shl 4);
       temp := ((right shr 16) xor left) and $0000ffff; left := left xor temp; right :=right xor (temp shl 16);
       temp := ((left shr 2) xor right) and $33333333; right :=right xor temp; left := left xor (temp shl 2);
       temp := ((right shr 16) xor left) and $0000ffff; left :=left xor temp; right := right xor (temp shl 16);
       temp := ((left shr 1) xor right) and $55555555; right := right xor temp; left := left xor (temp shl 1);
       temp := ((right shr 8) xor left) and $00ff00ff; left :=left xor temp; right := right xor (temp shl 8);
       temp := ((left shr 1) xor right) and $55555555; right :=right xor temp; left := left xor (temp shl 1);

       //the right side needs to be shifted and to get the last four bits of the left side
       temp := (left shl 8) or ((right shr 20) and $000000f0);
       //left needs to be put upside down
       left := (right shl 24) or ((right shl 8) and $ff0000) or ((right shr 8) and $ff00) or ((right shr 24) and $f0);
       right := temp;

       //now go through and perform these shifts on the left and right keys
       for i:=low(shifts) to   high(shifts) do
         begin
           //shift the keys either one or two bits to the left
           if shifts[i] > 0 then
             begin
               left := (left shl 2) or (left shr 26);
               right := (right shl 2) or (right shr 26);
               //left := left shl 0;
               //right:= right shl 0;
             end
           else
             begin
               left := (left shl 1) or (left shr 27);
               right := (right shl 1) or (right shr 27);
               //left := left shl 0;
               //right:= right shl 0;
             end;

           left := left and $fffffff0;
           right:= right and $fffffff0;

           //now apply PC-2, in such a way that E is easier when encrypting or decrypting
           //this conversion will look like PC-2 except only the last 6 bits of each byte are used
           //rather than 48 consecutive bits and the order of lines will be according to
           //how the S selection functions will be applied: S2, S4, S6, S8, S1, S3, S5, S7
           lefttemp := pc2bytes0[left shr 28] or pc2bytes1[(left shr 24) and $f]
                       or pc2bytes2[(left shr 20) and $f] or pc2bytes3[(left shr 16) and $f]
                       or pc2bytes4[(left shr 12) and $f] or pc2bytes5[(left shr 8) and $f]
                       or pc2bytes6[(left shr 4) and $f];
           righttemp := pc2bytes7[right shr 28] or pc2bytes8[(right shr 24) and $f]
                        or pc2bytes9[(right shr 20) and $f] or pc2bytes10[(right shr 16) and $f]
                        or pc2bytes11[(right shr 12) and $f] or pc2bytes12[(right shr 8) and $f]
                        or pc2bytes13[(right shr 4) and $f];
           temp := ((righttemp shr 16) xor lefttemp) and $0000ffff;
           keys[n+0] := lefttemp xor temp;
           keys[n+1] := righttemp xor (temp shl 16);
           n:=n+2;
         end;
     end; //for each iterations

   //return the keys we've created
   Result := keys;

end;//end of des_createKeys


function StrToHex(Str:string):string;
var
   i:integer;
begin
   result := '';
   for i := 1 to length(Str) do
     result := result + IntToHex(Ord(Str[i]), 2);
end;

function HexToStr(Hex:string):string;
var
   i:Integer;
begin
   Result := '';
   for i := 1 to length(Hex) div 2 do
     if IsInt('$' + Hex[i * 2 - 1] + Hex[i * 2]) then
       Result := Result + Chr(StrToInt('$' + Hex[i * 2 - 1] + Hex[i * 2]));
end;

function IsInt(Str:String):Boolean;
begin
   result := True;
   try
     StrToInt(Str);
   except
     result := False
   end;
end;

end.
