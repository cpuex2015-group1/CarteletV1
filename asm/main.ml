module TagDict = Map.Make(String)

let rec print_str_list l =
    match l with
    | [] -> ()
    | e :: l' -> Printf.printf "%s\n" e; print_str_list l'

let rec print_triple_list xs =
    match xs with
    | [] -> ()
    | (i1, i2, str) :: xs' -> Printf.printf "(%d, %d, %s)\n" i1 i2 str; print_triple_list xs'

let rec print_double_list xs =
    match xs with
    | [] -> ()
    | (i1, str) :: xs' -> Printf.printf "(%d, %s)\n" i1 str; print_double_list xs'

let half_byte_to_hex hb =
    match hb with
    | "0000" -> "0"
    | "0001" -> "1"
    | "0010" -> "2"
    | "0011" -> "3"
    | "0100" -> "4"
    | "0101" -> "5"
    | "0110" -> "6"
    | "0111" -> "7"
    | "1000" -> "8"
    | "1001" -> "9"
    | "1010" -> "a"
    | "1011" -> "b"
    | "1100" -> "c"
    | "1101" -> "d"
    | "1110" -> "e"
    | "1111" -> "f"
    | _ -> raise (Failure "matching failed in half_byte_to_hex")

let hex_to_half_byte hex =
    match hex with
    | "0" -> "0000"
    | "1" -> "0001"
    | "2" -> "0010"
    | "3" -> "0011"
    | "4" -> "0100"
    | "5" -> "0101"
    | "6" -> "0110"
    | "7" -> "0111"
    | "8" -> "1000"
    | "9" -> "1001"
    | "A" | "a" -> "1010"
    | "B" | "b" -> "1011"
    | "C" | "c" -> "1100"
    | "D" | "d" -> "1101"
    | "E" | "e" -> "1110"
    | "F" | "f" -> "1111"
    | _ -> raise (Failure "matching failed in hex_to_half_byte")

let rec to_bin dec =
    let half = dec / 2 in
    if dec mod 2 = 0 then
        if half > 0 then
            to_bin half ^ "0"
        else
            ""
    else
        to_bin half ^ "1"

let rec not' binstr =
    if String.length binstr > 0 then
        let car = String.sub binstr 0 1 in
        let cdr = String.sub binstr 1 (String.length binstr - 1) in
        match car with
        | "0" -> "1" ^ not' cdr
        | "1" -> "0" ^ not' cdr
        | _ -> raise (Failure "matching failed in not'")
    else
        ""

let rec to_dec binstr =
    if String.length binstr > 0 then
        let head = String.sub binstr 0 (String.length binstr - 1) in
        let tail = String.sub binstr (String.length binstr - 1) 1 in
        int_of_string tail + 2 * to_dec head
    else
        0

let neg binstr =
    to_bin (to_dec (not' binstr) + 1)

let rec zfill str num =
    if String.length str < num then
        zfill ("0" ^ str) num
    else
        str

let reg_to_bin str =
    let num = int_of_string (String.sub str 2 (String.length str - 2)) in (* %r とかを読み飛ばす*)
    zfill (to_bin num) 5

let rec repeat str num =
    if num > 0 then
        str ^ repeat str (num - 1)
    else ""

let dec_imm_to_bin str =
    let car = String.sub str 0 1 in
    let cdr = String.sub str 1 (String.length str - 1) in
    match car with
    | "-" -> neg (zfill (to_bin (int_of_string cdr)) 16)
    | _   -> zfill (to_bin (int_of_string str)) 16

(* hex をそのまま bin にするだけ (符号は非対応) *)
let rec hex_imm_to_bin str =
    if String.length str > 0 then
        let car = String.sub str 0 1 in
        let cdr = String.sub str 1 (String.length str - 1) in
        hex_to_half_byte car ^ hex_imm_to_bin cdr
    else
        ""

let imm_to_bin' str =
    if String.length str > 2 &&  String.sub str 0 2 = "0x" then
        zfill (hex_imm_to_bin (String.sub str 2 (String.length str - 2))) 16
    else if String.length str > 2 &&  String.sub str 0 2 = "0b" then
        zfill (String.sub str 2 (String.length str - 2)) 16
    else
        dec_imm_to_bin str

let imm_to_bin str =
    let res = imm_to_bin' (String.sub str 1 (String.length str - 1)) in
    if String.length res <= 16 then
        res
    else
        raise (Failure "immediate overflow")

let imm_to_bin_unlimited str =
    imm_to_bin' (String.sub str 1 (String.length str - 1))

let dsp_to_bin str =
    let res = imm_to_bin' str in
    if String.length res <= 16 then
        res
    else
        raise (Failure "immediate overflow")

let tag_to_bin str line tag_dict =
    let target_line = TagDict.find str tag_dict in
    dsp_to_bin (string_of_int (target_line - line - 1))

let abs_tag_to_bin str line tag_dict =
    let target_line = TagDict.find str tag_dict in
    dsp_to_bin (string_of_int (target_line))

let imm_or_abs_tag_to_bin str line tag_dict =
    if TagDict.exists (fun key _ -> key = str) tag_dict then
        abs_tag_to_bin str line tag_dict
    else
        imm_to_bin str

let tag_counter = ref 0

let get_fresh_tag () =
    tag_counter := !tag_counter + 1;
    "_asm_tag" ^ string_of_int !tag_counter

let first_half_of_imm imm =
    let binstr = imm_to_bin_unlimited imm in
    String.sub (zfill binstr 32) 0 16

let last_half_of_imm imm =
    let binstr = imm_to_bin_unlimited imm in
    String.sub (zfill binstr 32) 16 16

let convert_pseudo_ops' line asm =
    let tokens = Str.split (Str.regexp "[ \t()]+") asm in
    let head = List.hd tokens in
    let (label, tokens) = if String.sub head (String.length head - 1) 1 = ":" then ([(line, head)], List.tl tokens) else ([], tokens) in
    if List.length tokens > 0 then
        match List.hd tokens with
        | "jalr" ->
            let tag = get_fresh_tag () in
            label @
            [(line, "addiu %r31 %r0 " ^ tag);
             (line, "jr " ^ List.nth tokens 1);
             (line, tag ^ ":")]
        | "addiu32" ->
            label @
            [(line, "addi %r1 %r0 $16");
            (line, "addiu " ^ List.nth tokens 1 ^ " %r0 $0b" ^ first_half_of_imm (List.nth tokens 3));
            (line, "sll " ^ List.nth tokens 1 ^ " " ^ List.nth tokens 1 ^ " %r1");
            (line, "addiu " ^ List.nth tokens 1 ^ " " ^ List.nth tokens 1 ^ " $0b" ^ last_half_of_imm (List.nth tokens 3))]
        | _ -> [(line, asm)]
    else
        [(line, asm)]


let rec convert_pseudo_ops text =
    let converted = List.flatten (List.map (fun (line, asm) -> convert_pseudo_ops' line asm) text) in
    if converted = text then
        converted
    else
        convert_pseudo_ops converted

let asm_to_bin line str tag_dict =
    Printf.eprintf "%s\n" str;
    let tokens = Str.split (Str.regexp "[ \t()]+") str in
    match List.hd tokens with
    | "nop"  -> repeat "0" 32
    | "add"  -> "000001" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^
                           reg_to_bin (List.nth tokens 3) ^ repeat "0" 11
    | "addi" -> "000010" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^
                           imm_or_abs_tag_to_bin (List.nth tokens 3) line tag_dict
    | "sub"  -> "000011" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^
                           reg_to_bin (List.nth tokens 3) ^ repeat "0" 11
    | "subi" -> "000100" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^
                           imm_to_bin (List.nth tokens 3)
    | "sll"  -> "000101" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^
                           reg_to_bin (List.nth tokens 3) ^ repeat "0" 11
    | "srl"  -> "000110" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^
                           reg_to_bin (List.nth tokens 3) ^ repeat "0" 11
    | "st"   -> "001000" ^ reg_to_bin (List.nth tokens 2) ^
                           reg_to_bin (List.nth tokens 3) ^
                           dsp_to_bin (List.nth tokens 1)
    | "ld"   -> "001001" ^ reg_to_bin (List.nth tokens 2) ^
                           reg_to_bin (List.nth tokens 3) ^
                           dsp_to_bin (List.nth tokens 1)
    | "beq"  -> "010000" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^
                           tag_to_bin (List.nth tokens 3) line tag_dict
    | "bneq" -> "010001" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^
                           tag_to_bin (List.nth tokens 3) line tag_dict
    | "jal"  -> "010011" ^ repeat "0" 10 ^
                           abs_tag_to_bin (List.nth tokens 1) line tag_dict
    | "slt"  -> "010100" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^
                           reg_to_bin (List.nth tokens 3) ^ repeat "0" 11
    | "bclt" -> "010101" ^ repeat "0" 10 ^
                           tag_to_bin (List.nth tokens 1) line tag_dict
    | "bclf" -> "010110" ^ repeat "0" 10 ^
                           tag_to_bin (List.nth tokens 1) line tag_dict
    | "addiu"-> "010111" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^
                           imm_or_abs_tag_to_bin (List.nth tokens 3) line tag_dict
    | "jr"   -> "010010" ^ reg_to_bin (List.nth tokens 1) ^ repeat "0" 21
    | "send" -> "100000" ^ reg_to_bin (List.nth tokens 1) ^ repeat "0" 21
    | "halt" -> "100001" ^ repeat "0" 26
    | "send8"-> "100010" ^ reg_to_bin (List.nth tokens 1) ^ repeat "0" 21
    | "recv8"-> "100011" ^ reg_to_bin (List.nth tokens 1) ^ repeat "0" 21
    | "fadd" -> "110000" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^
                           reg_to_bin (List.nth tokens 3) ^ repeat "0" 11
    | "fmul" -> "110001" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^
                           reg_to_bin (List.nth tokens 3) ^ repeat "0" 11
    | "finv" -> "110010" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^ repeat "0" 16
    | "fneg" -> "110011" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^ repeat "0" 16
    | "fabs" -> "110100" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^ repeat "0" 16
    | "fst"  -> "110101" ^ reg_to_bin (List.nth tokens 2) ^
                           reg_to_bin (List.nth tokens 3) ^
                           dsp_to_bin (List.nth tokens 1)
    | "fld"  -> "110110" ^ reg_to_bin (List.nth tokens 2) ^
                           reg_to_bin (List.nth tokens 3) ^
                           dsp_to_bin (List.nth tokens 1)
    | "fseq" -> "110111" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^ repeat "0" 16
    | "fslt" -> "111000" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^ repeat "0" 16
    | "fmov" -> "111001" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^ repeat "0" 16
    | "fsqrt"-> "111010" ^ reg_to_bin (List.nth tokens 1) ^
                           reg_to_bin (List.nth tokens 2) ^ repeat "0" 16
    | _ -> raise (Failure "matching failed in asm_to_bin")

let rec split_by_num str num =
    let l = String.length str in
    if l > num then
        String.sub str 0 num :: split_by_num (String.sub str num (l - num)) num
    else
        [str]

let bin_to_hex str =
    let str = (
        let r = String.length str mod 4 in
        if r != 0 then
            repeat "0" (4 - r) ^ str
        else
            str) in
    let half_bytes = split_by_num str 4 in
    List.fold_left (fun acc hb -> acc ^ half_byte_to_hex hb) "" half_bytes


let asm_to_hex line str tag_dict =
    bin_to_hex (asm_to_bin line str tag_dict)

let remove_comment str =
    try
        String.sub str 0 (String.index str '#')
    with Not_found -> str

let assemble asms tag_dict mode =
    let asms = List.filter (fun (_, x) -> not (Str.string_match (Str.regexp "[\t ]*$") x 0)) (List.rev_map (fun (line, str) -> (line, remove_comment str)) asms) in
    if mode = "hexstr" then
        List.fold_left (fun acc (line, asm) -> acc ^ asm_to_hex line asm tag_dict) "" asms
    else
        List.fold_left (fun acc (line, asm) -> acc ^ "x\"" ^ asm_to_hex line asm tag_dict ^ "\",\n") "" asms

let rec extract_data' data asms =
    match asms with
    | [] -> data
    | (_, asm) :: asms' when asm = ".text" -> data
    | (_, asm) :: asms' when asm = ".data" -> extract_data' data asms'
    | lineasm :: asms' -> extract_data' (data @ [lineasm]) asms'

let extract_data asms =
    extract_data' [] asms

let rec extract_text asms =
    match asms with
    | [] -> []
    | (_, asm) :: asms' when asm = ".text" -> asms'
    | _ :: asms' -> extract_text asms'

let rec trim_spaces_forward str =
    if String.length str > 0 then
        let car = String.sub str 0 1 in
        let cdr = String.sub str 1 (String.length str - 1) in
        match car with
        | "\t" | " " -> trim_spaces_forward cdr
        | _ -> str
    else
        str

let rec trim_spaces_backward str =
    if String.length str > 0 then
        let tl = String.sub str (String.length str - 1) 1 in
        let hd = String.sub str 0 (String.length str - 1) in
        match tl with
        | "\t" | " " -> trim_spaces_backward hd
        | _ -> str
    else
        str

let rec trim_comment asms =
    if asms = [] then
        []
    else
        let (line, asm) = List.hd asms in
        if Str.string_match (Str.regexp "^[\t ]*$") asm 0 then
            trim_comment (List.tl asms)
        else if Str.string_match (Str.regexp "^[\t ]*#.*$") asm 0 then
            trim_comment (List.tl asms)
        else
            let asm = (try
                String.sub asm 0 (String.index asm '#')
            with Not_found -> asm) in
            let asm = trim_spaces_forward (trim_spaces_backward asm) in
            (line, asm) :: trim_comment (List.tl asms)

let optimize text = (* TODO *)
    text

let is_tag_def str =
    Str.string_match (Str.regexp "^.*:$") str 0

let has_tag_def str =
    Str.string_match (Str.regexp "^.*:") str 0

let get_tag_def str = (* raises Not_found exception *)
    String.sub str 0 (String.index str ':')

let remove_tag_def str =
    try
        let index = String.index str ':' in
        trim_spaces_forward (String.sub str (index + 1) (String.length str - index - 1))
    with Not_found -> str

let rec attach_logical_line_num' num text =
    match text with
    | [] -> []
    | (line, asm) :: asms' when is_tag_def asm -> (num, line, asm) :: attach_logical_line_num' num asms'
    | (line, asm) :: asms' -> (num, line, asm) :: attach_logical_line_num' (num + 1) asms'

let attach_logical_line_num text =
    attach_logical_line_num' 0 text

let rec create_tag_dict' tag_dict text =
    match text with
    | [] -> tag_dict
    | (lline, pline, asm) :: asms' when has_tag_def asm -> create_tag_dict' (TagDict.add (get_tag_def asm) lline tag_dict) asms'
    | asm :: asms' -> create_tag_dict' tag_dict asms'

let create_tag_dict text =
    create_tag_dict' TagDict.empty text

let rec strip_tag_def asms =
    match asms with
    | [] -> []
    | (lline, pline, asm) :: asms' when is_tag_def asm -> strip_tag_def asms'
    | (lline, pline, asm) :: asms' when has_tag_def asm -> (lline, pline, remove_tag_def asm) :: strip_tag_def asms'
    | asm :: asms' -> asm :: strip_tag_def asms'

let has_globl str =
    Str.string_match (Str.regexp "[.]globl") str 0

let get_globl_tag str =
    let tokens = Str.split (Str.regexp "[ \t]+") str in
    List.nth tokens 1

let rec get_entry_point text =
    match text with
    | [] -> raise (Failure "entry point not found")
    | (_, asm) :: asms' when has_globl asm -> get_globl_tag asm
    | asm :: asms' -> get_entry_point asms'

let rec remove_entry_point_mark text =
    match text with
    | [] -> []
    | (_, asm) :: asms' when has_globl asm -> asms'
    | asm :: asms' -> asm :: remove_entry_point_mark asms'

let output_format = ref "h" (* Hexstr Simulator Object Binary *)

let rec output_format_sim prog =
    match prog with
    | [] -> ()
    | l :: prog' -> Printf.printf "\"%s\",\n" l; output_format_sim prog'

let rec output_format_hex prog =
    match prog with
    | [] -> ()
    | l :: prog' -> Printf.printf "%s" (bin_to_hex l); output_format_hex prog'

let rec int32_of_bin' i32 bin =
    if String.length bin > 0 then
        let car = String.sub bin 0 1 in
        let cdr = String.sub bin 1 (String.length bin - 1) in
        let two = Int32.add Int32.one Int32.one in
        match car with
        | "0" -> int32_of_bin' (Int32.mul i32 two) cdr
        | "1" -> int32_of_bin' (Int32.add (Int32.mul i32 two) Int32.one) cdr
        | _ -> raise (Failure "matching failed in int32_of_bin'")
    else
        i32

let int32_of_bin bin =
    int32_of_bin' Int32.zero bin

let output_int32 i =
    output_byte stdout (Int32.to_int (Int32.shift_right i 24));
    output_byte stdout (Int32.to_int (Int32.shift_right i 16));
    output_byte stdout (Int32.to_int (Int32.shift_right i 8));
    output_byte stdout (Int32.to_int i)

let rec output_format_obj prog =
    match prog with
    | [] -> ()
    | l :: prog' -> output_int32 (int32_of_bin l); output_format_obj prog'

let main' asms =
    let asms = trim_comment asms in
    let data = attach_logical_line_num (extract_data asms) in
    let data_tag_dict = create_tag_dict data in
    let data = strip_tag_def data in
    let data' = List.map (fun (_, _, d) -> let tokens = Str.split (Str.regexp "[ \t()]+") d in (Printf.eprintf "%s\n" (List.nth tokens 1)); imm_to_bin' (List.nth tokens 1)) data in
    let text = extract_text asms in
    let entry_point = get_entry_point text in
    let text = remove_entry_point_mark text in
    let text = convert_pseudo_ops text in
    let text = optimize text in
    let text = [(-1, "addi %r3 %r0 $0x00aa"); (-1, "send8 %r3")] @ [(-1, "beq %r0 %r0 " ^ entry_point)] @ text in
    let text' = attach_logical_line_num text in
    let tag_dict = TagDict.merge (fun key a b -> if a = None then b else a) data_tag_dict (create_tag_dict text') in
    let text' = strip_tag_def text' in
    let prog = List.map (fun (lline, _, asm) -> asm_to_bin lline asm tag_dict) text' in
    let prog =
        [("00000010" ^ zfill (to_bin (List.length data')) 24)] @
        data' @
        [("00000001" ^ zfill (to_bin (List.length prog)) 24)] @
        prog @
        ["00000011000000000000000000000000"] in
    match !output_format with
    | "h" -> output_format_hex prog; Printf.printf "\n"
    | "s" -> Printf.eprintf "%d, %s\n" (List.length prog) (bin_to_hex (to_bin (List.length prog))); output_format_sim prog
    | "o" -> output_format_obj prog
    | _ -> raise (Failure (Printf.sprintf "Unknown output format: %s" !output_format))

let () =
    Arg.parse
        [("-format", Arg.String(fun s -> output_format := s), "output format (h, s, o, b)")]
        (fun file ->
            let ic = open_in file in
            let asms = ref [] in
            let line = ref 1 in
            try
                while true do
                    let asm = input_line ic in
                    asms := !asms @ [(!line, asm)];
                    line := !line + 1
                done
            with End_of_file ->
                main' !asms;
                close_in ic)
        (Printf.sprintf "Cartelet V1 assembler\nusage: %s [-format h,s,o,b] filename" Sys.argv.(0))
