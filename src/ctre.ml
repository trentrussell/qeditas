(* Copyright (c) 2015 The Qeditas developers *)
(* Distributed under the MIT software license, see the accompanying
   file COPYING or http://www.opensource.org/licenses/mit-license.php. *)

open Ser
open Hash
open Mathdata
open Assets
open Cryptocurr
open Tx
open Config

let intention_minage = 144L

type hlist = HHash of hashval | HNil | HCons of asset * hlist

let rec hlist_hashroot hl =
  match hl with
  | HHash(h) -> Some(h)
  | HNil -> None
  | HCons(a,hr) ->
      begin
	match hlist_hashroot hr with
	| None -> Some(hashtag (hashasset a) 3l)
	| Some(k) -> Some(hashtag (hashpair (hashasset a) k) 4l)
      end

type nehlist = NehHash of hashval | NehCons of asset * hlist

let nehlist_hlist hl =
  match hl with
  | NehHash(h) -> HHash h
  | NehCons(a,hr) -> HCons(a,hr)

let nehlist_hashroot hl =
  match hl with
  | NehHash(h) -> h
  | NehCons(a,hr) ->
      begin
	match hlist_hashroot hr with
	| None -> hashtag (hashasset a) 3l
	| Some(k) -> hashtag (hashpair (hashasset a) k) 4l
      end

let rec in_hlist a hl =
  match hl with
  | HCons(b,hr) when a = b -> true
  | HCons(_,hr) -> in_hlist a hr
  | _ -> false

let in_nehlist a hl =
  match hl with
  | NehCons(b,hr) when a = b -> true
  | NehCons(_,hr) -> in_hlist a hr
  | _ -> false

let rec hlist_lookup_asset k hl =
  match hl with
  | HCons(a,hr) when assetid a = k -> Some(a)
  | HCons(_,hr) -> hlist_lookup_asset k hr
  | _ -> None

let nehlist_lookup_asset k hl =
  match hl with
  | NehCons(a,hr) when assetid a = k -> Some(a)
  | NehCons(_,hr) -> hlist_lookup_asset k hr
  | _ -> None

let rec hlist_lookup_marker hl =
  match hl with
  | HCons(a,hr) when assetpre a = Marker -> Some(a)
  | HCons(_,hr) -> hlist_lookup_marker hr
  | _ -> None

let nehlist_lookup_marker hl =
  match hl with
  | NehCons(a,hr) when assetpre a = Marker -> Some(a)
  | NehCons(_,hr) -> hlist_lookup_marker hr
  | _ -> None

let rec hlist_lookup_obj_owner hl =
  match hl with
  | HCons((_,_,_,OwnsObj(beta,r)),hr) -> Some(beta,r)
  | HCons(_,hr) -> hlist_lookup_obj_owner hr
  | _ -> None

let nehlist_lookup_obj_owner hl =
  match hl with
  | NehCons((_,_,_,OwnsObj(beta,r)),hr) -> Some(beta,r)
  | NehCons(_,hr) -> hlist_lookup_obj_owner hr
  | _ -> None

let rec hlist_lookup_prop_owner hl =
  match hl with
  | HCons((_,_,_,OwnsProp(beta,r)),hr) -> Some(beta,r)
  | HCons(_,hr) -> hlist_lookup_prop_owner hr
  | _ -> None

let nehlist_lookup_prop_owner hl =
  match hl with
  | NehCons((_,_,_,OwnsProp(beta,r)),hr) -> Some(beta,r)
  | NehCons(_,hr) -> hlist_lookup_prop_owner hr
  | _ -> None

let rec hlist_lookup_neg_prop_owner hl =
  match hl with
  | HCons((_,_,_,OwnsNegProp),hr) -> true
  | HCons(_,hr) -> hlist_lookup_neg_prop_owner hr
  | _ -> false

let nehlist_lookup_neg_prop_owner hl =
  match hl with
  | NehCons((_,_,_,OwnsNegProp),hr) -> true
  | NehCons(_,hr) -> hlist_lookup_neg_prop_owner hr
  | _ -> false

type frame =
  | FHash
  | FAbbrev of frame
  | FAll
  | FLeaf of bool list * int option
  | FBin of frame * frame

type ctree =
  | CLeaf of bool list * nehlist
  | CHash of hashval
  | CAbbrev of hashval * hashval
  | CLeft of ctree
  | CRight of ctree
  | CBin of ctree * ctree

let rec print_ctree_r c n =
  for i = 1 to n do Printf.printf " " done;
  match c with
  | CLeaf(bl,hl) -> Printf.printf "Leaf\n"
  | CHash(h) -> Printf.printf "H %s\n" (hashval_hexstring h)
  | CAbbrev(hr,ha) -> Printf.printf "A %s %s\n" (hashval_hexstring hr) (hashval_hexstring ha)
  | CLeft(c0) -> Printf.printf "L\n"; print_ctree_r c0 (n+1)
  | CRight(c1) -> Printf.printf "R\n"; print_ctree_r c1 (n+1)
  | CBin(c0,c1) -> Printf.printf "B\n"; print_ctree_r c0 (n+1); print_ctree_r c1 (n+1)

let print_ctree c = print_ctree_r c 0

let rec print_hlist hl =
  match hl with
  | HHash(h) -> Printf.printf "...%s...\n" (hashval_hexstring h)
  | HNil -> ()
  | HCons((aid,bday,obl,Currency(v)),hr) ->
      begin
	Printf.printf "%s [%Ld] Currency %Ld\n" (hashval_hexstring aid) bday v;
	print_hlist hr
      end
  | HCons((aid,bday,obl,Bounty(v)),hr) ->
      begin
	Printf.printf "%s [%Ld] Bounty %Ld\n" (hashval_hexstring aid) bday v;
	print_hlist hr
      end
  | HCons((aid,bday,obl,OwnsObj(gamma,Some(r))),hr) ->
      begin
	Printf.printf "%s [%Ld] OwnsObj %s %Ld\n" (hashval_hexstring aid) bday (addr_qedaddrstr (payaddr_addr gamma)) r;
	print_hlist hr
      end
  | HCons((aid,bday,obl,OwnsObj(gamma,None)),hr) ->
      begin
	Printf.printf "%s [%Ld] OwnsObj %s None\n" (hashval_hexstring aid) bday (addr_qedaddrstr (payaddr_addr gamma));
	print_hlist hr
      end
  | HCons((aid,bday,obl,OwnsProp(gamma,Some(r))),hr) ->
      begin
	Printf.printf "%s [%Ld] OwnsProp %s %Ld\n" (hashval_hexstring aid) bday (addr_qedaddrstr (payaddr_addr gamma)) r;
	print_hlist hr
      end
  | HCons((aid,bday,obl,OwnsProp(gamma,None)),hr) ->
      begin
	Printf.printf "%s [%Ld] OwnsProp %s None\n" (hashval_hexstring aid) bday (addr_qedaddrstr (payaddr_addr gamma));
	print_hlist hr
      end
  | HCons((aid,bday,obl,OwnsNegProp),hr) ->
      begin
	Printf.printf "%s [%Ld] OwnsNegProp\n" (hashval_hexstring aid) bday;
	print_hlist hr
      end
  | HCons((aid,bday,obl,RightsObj(gamma,r)),hr) ->
      begin
	Printf.printf "%s [%Ld] RightsObj %s %Ld\n" (hashval_hexstring aid) bday (addr_qedaddrstr (termaddr_addr gamma)) r;
	print_hlist hr
      end
  | HCons((aid,bday,obl,RightsProp(gamma,r)),hr) ->
      begin
	Printf.printf "%s [%Ld] RightsProp %s %Ld\n" (hashval_hexstring aid) bday (addr_qedaddrstr (termaddr_addr gamma)) r;
	print_hlist hr
      end
  | HCons((aid,bday,obl,v),hr) ->
      begin
	Printf.printf "%s [%Ld]\n" (hashval_hexstring aid) bday;
	print_hlist hr
      end

let rec print_ctree_all_r c n br =
  for i = 1 to n do Printf.printf " " done;
  match c with
  | CLeaf(bl,hl) -> Printf.printf "Leaf %s\n" (addr_qedaddrstr (bitseq_addr ((List.rev br) @ bl))); print_hlist (nehlist_hlist hl)
  | CHash(h) -> Printf.printf "H %s\n" (hashval_hexstring h)
  | CAbbrev(hr,ha) -> Printf.printf "A %s %s\n" (hashval_hexstring hr) (hashval_hexstring ha)
  | CLeft(c0) -> Printf.printf "L\n"; print_ctree_all_r c0 (n+1) (false::br)
  | CRight(c1) -> Printf.printf "R\n"; print_ctree_all_r c1 (n+1) (true::br)
  | CBin(c0,c1) -> Printf.printf "B\n"; print_ctree_all_r c0 (n+1) (false::br); print_ctree_all_r c1 (n+1) (true::br)

let print_ctree_all c = print_ctree_all_r c 0 []

let print_octree_all_r c n br =
  match c with
  | Some(c) -> print_ctree_all_r c n br
  | None -> ()

let rec ctree_hashroot c =
  match c with
  | CLeaf(bl,hl) ->
      List.fold_right
	(fun b h ->
	  if b then
	    hashopair2 None h
	  else
	    hashopair1 h None
	)
	bl (nehlist_hashroot hl)
  | CHash(h) -> h
  | CAbbrev(hr,ha) -> hr
  | CLeft(c0) -> hashopair1 (ctree_hashroot c0) None
  | CRight(c1) -> hashopair2 None (ctree_hashroot c1)
  | CBin(c0,c1) -> hashopair1 (ctree_hashroot c0) (Some (ctree_hashroot c1))

let rec hashhlist hl =
  match hl with
  | HHash(h) -> hashtag h 149l
  | HCons(a,hr) -> hashtag (hashpair (hashasset a) (hashhlist hr)) 150l
  | HNil -> hashint32 151l

let hashnehlist hl =
  match hl with
  | NehHash(h) -> hashtag h 147l
  | NehCons(a,hr) -> hashtag (hashpair (hashasset a) (hashhlist hr)) 148l

let rec hashctree c =
  match c with
  | CLeaf(bl,hl) -> hashtag (hashpair (hashbitseq bl) (hashnehlist hl)) 141l
  | CHash(h) -> hashtag h 142l
  | CAbbrev(hr,ha) -> hashtag (hashpair hr ha) 143l
  | CLeft(c0) -> hashtag (hashctree c0) 144l
  | CRight(c1) -> hashtag (hashctree c1) 145l
  | CBin(c0,c1) -> hashtag (hashpair (hashctree c0) (hashctree c1)) 146l

let rec ctree_numnodes c =
  match c with
  | CLeaf(_,_) -> 1
  | CHash(_) -> 1
  | CAbbrev(_,_) -> 1
  | CLeft(c) -> 1 + ctree_numnodes c
  | CRight(c) -> 1 + ctree_numnodes c
  | CBin(c0,c1) -> 1 + ctree_numnodes c0 + ctree_numnodes c1

let octree_numnodes oc =
  match oc with
  | None -> 0
  | Some(c) -> ctree_numnodes c

let octree_hashroot c =
  match c with
  | Some(c) -> Some(ctree_hashroot c)
  | None -> None

let rec strip_bitseq_false l =
  match l with
  | [] -> []
  | ((false::bl),x)::r -> (bl,x)::strip_bitseq_false r
  | ((true::bl),x)::r -> strip_bitseq_false r
  | _ -> raise (Failure "bitseq length error")
  
let rec strip_bitseq_true l =
  match l with
  | [] -> []
  | ((true::bl),x)::r -> (bl,x)::strip_bitseq_true r
  | ((false::bl),x)::r -> strip_bitseq_true r
  | _ -> raise (Failure "bitseq length error")

let rec strip_bitseq_false0 l =
  match l with
  | [] -> []
  | (false::bl)::r -> bl::strip_bitseq_false0 r
  | (true::bl)::r -> strip_bitseq_false0 r
  | _ -> raise (Failure "bitseq length error")
  
let rec strip_bitseq_true0 l =
  match l with
  | [] -> []
  | (true::bl)::r -> bl::strip_bitseq_true0 r
  | (false::bl)::r -> strip_bitseq_true0 r
  | _ -> raise (Failure "bitseq length error")

let rec hlist_new_assets nw old =
  match nw with
  | [] -> old
  | a::nwr -> HCons(a,hlist_new_assets nwr old)

let rec remove_assets_hlist hl spent =
  match hl with
  | HCons((h,bh,obl,u) as a,hr) ->
      if List.mem h spent then
	remove_assets_hlist hr spent
      else
	HCons(a,remove_assets_hlist hr spent)
  | _ -> hl

let octree_S_inv c =
  match c with
  | None -> (None,None)
  | Some(CHash(h)) ->
      raise Not_found
  | Some(CAbbrev(hr,ha)) ->
      raise Not_found
  | Some(CLeaf([],hl)) ->
      raise Not_found
  | Some(CLeaf(false::bl,hl)) -> (Some(CLeaf(bl,hl)),None)
  | Some(CLeaf(true::bl,hl)) -> (None,Some(CLeaf(bl,hl)))
  | Some(CLeft(c0)) -> (Some(c0),None)
  | Some(CRight(c1)) -> (None,Some(c1))
  | Some(CBin(c0,c1)) -> (Some(c0),Some(c1))

let rec tx_octree_trans_ n inpl outpl c =
  if inpl = [] && outpl = [] then
    c
  else if n > 0 then
    begin
      match octree_S_inv c with
      | (c0,c1) ->
	  match
	    tx_octree_trans_ (n-1) (strip_bitseq_false inpl) (strip_bitseq_false outpl) c0,
	    tx_octree_trans_ (n-1) (strip_bitseq_true inpl) (strip_bitseq_true outpl) c1
	  with
	  | None,None -> None
	  | Some(CLeaf(bl,hl)),None -> Some(CLeaf(false::bl,hl))
	  | Some(c0r),None -> Some(CLeft(c0r))
	  | None,Some(CLeaf(bl,hl)) -> Some(CLeaf(true::bl,hl))
	  | None,Some(c1r) -> Some(CRight(c1r))
	  | Some(c0r),Some(c1r) -> Some(CBin(c0r,c1r))
    end
  else
    begin
      let hl =
	begin
	  match c with
	  | Some(CLeaf([],hl)) -> nehlist_hlist hl
	  | None -> HNil
	  | _ -> raise (Failure "not a ctree 0")
	end
      in
      let hl2 = hlist_new_assets (List.map (fun (x,y) -> y) outpl) (remove_assets_hlist hl (List.map (fun (x,y) -> y) inpl)) in
      match hl2 with
      | HNil -> None
      | HHash(h) -> Some(CLeaf([],NehHash(h)))
      | HCons(a,hr) -> Some(CLeaf([],NehCons(a,hr)))
    end

let add_vout bh txh outpl =
  let i = ref 0 in
  let r = ref [] in
  List.iter
    (fun (alpha,(obl,u)) ->
      r := (addr_bitseq alpha,(hashpair txh (hashint32 (Int32.of_int !i)),bh,obl,u))::!r;
      incr i;
    )
    outpl;
  !r

let tx_octree_trans bh tx c =
  let (inpl,outpl) = tx in
  tx_octree_trans_ 162
    (List.map (fun (alpha,h) -> (addr_bitseq alpha,h)) inpl)
    (add_vout bh (hashtx tx) outpl)
    c

let rec txl_octree_trans bh txl c =
  match txl with
  | (tx::txr) -> txl_octree_trans bh txr (tx_octree_trans bh tx c)
  | [] -> c

(** * serialization **)
let rec seo_hlist o hl c =
  match hl with
  | HHash(h) -> (* 0 0 *)
      let c = o 2 0 c in
      seo_hashval o h c
  | HNil -> (* 0 1 *)
      let c = o 2 2 c in
      c
  | HCons(a,hr) -> (* 1 *)
      let c = o 1 1 c in
      let c = seo_asset o a c in
      seo_hlist o hr c

let rec sei_hlist i c =
  let (x,c) = i 1 c in
  if x = 0 then
    let (x,c) = i 1 c in
    if x = 0 then
      let (h,c) = sei_hashval i c in
      (HHash(h),c)
    else
      (HNil,c)
  else
    let (a,c) = sei_asset i c in
    let (hr,c) = sei_hlist i c in
    (HCons(a,hr),c)

let seo_nehlist o hl c =
  match hl with
  | NehHash(h) -> (* 0 *)
      let c = o 1 0 c in
      seo_hashval o h c
  | NehCons(a,hr) -> (* 1 *)
      let c = o 1 1 c in
      let c = seo_asset o a c in
      seo_hlist o hr c

let sei_nehlist i c =
  let (x,c) = i 1 c in
  if x = 0 then
    let (h,c) = sei_hashval i c in
    (NehHash(h),c)
  else
    let (a,c) = sei_asset i c in
    let (hr,c) = sei_hlist i c in
    (NehCons(a,hr),c)

let rec seo_frame o fr c =
  match fr with
  | FHash -> (* 00 *)
      o 2 0 c
  | FAbbrev(fra) -> (* 01 0 *)
      let c = o 3 1 c in
      seo_frame o fra c
  | FAll -> (* 01 1 *)
      o 3 5 c
  | FLeaf(bl,io) -> (* 10 *)
      let c = o 2 2 c in
      let c = seo_list seo_bool o bl c in
      seo_option seo_varint o
	(match io with
	| Some(i) -> Some(Int64.of_int i)
	| None -> None)
	c
  | FBin(frl,frr) -> (* 11 *)
      let c = o 2 3 c in
      let c = seo_frame o frl c in
      let c = seo_frame o frr c in
      c

let rec sei_frame i c =
  let (x,c) = i 2 c in
  if x = 0 then
    (FHash,c)
  else if x = 1 then
    let (y,c) = i 1 c in
    if y = 0 then
      let (fra,c) = sei_frame i c in
      (FAbbrev(fra),c)
    else
      (FAll,c)
  else if x = 2 then
    let (bl,c) = sei_list sei_bool i c in
    let (io,c) = sei_option sei_varint i c in
    let io2 = (match io with Some(i) -> Some(Int64.to_int i) | None -> None) in
    (FLeaf(bl,io2),c)
  else
    let (frl,c) = sei_frame i c in
    let (frr,c) = sei_frame i c in
    (FBin(frl,frr),c)

let rec seo_ctree o tr c =
  match tr with
  | CLeaf(bl,hl) -> (* 00 *)
      let c = o 2 0 c in
      let c = seo_list seo_bool o bl c in
      seo_nehlist o hl c
  | CHash(h) -> (* 01 0 *)
      let c = o 3 1 c in
      seo_hashval o h c
  | CAbbrev(hr,ha) -> (* 01 1 *)
      let c = o 3 5 c in
      let c = seo_hashval o hr c in
      seo_hashval o ha c
  | CLeft(trl) -> (* 10 0 *)
      let c = o 3 2 c in
      let c = seo_ctree o trl c in
      c
  | CRight(trr) -> (* 10 1 *)
      let c = o 3 6 c in
      let c = seo_ctree o trr c in
      c
  | CBin(trl,trr) -> (* 11 *)
      let c = o 2 3 c in
      let c = seo_ctree o trl c in
      let c = seo_ctree o trr c in
      c

let rec sei_ctree i c =
  let (x,c) = i 2 c in
  if x = 0 then
    let (bl,c) = sei_list sei_bool i c in
    let (hl,c) = sei_nehlist i c in
    (CLeaf(bl,hl),c)
  else if x = 1 then
    let (y,c) = i 1 c in
    let (h,c) = sei_hashval i c in
    if y = 0 then
      (CHash(h),c)
    else
      let (ha,c) = sei_hashval i c in
      (CAbbrev(h,ha),c)
  else if x = 2 then
    let (y,c) = i 1 c in
    let (tr,c) = sei_ctree i c in
    if y = 0 then
      (CLeft(tr),c)
    else
      (CRight(tr),c)
  else
    let (trl,c) = sei_ctree i c in
    let (trr,c) = sei_ctree i c in
    (CBin(trl,trr),c)

let rec reduce_hlist_to_approx al hl =
  match hl with
  | HNil -> HNil
  | HHash(h) -> HHash(h)
  | HCons((h1,bh1,o1,u1),hr) ->
      if al = [] then
	begin
	  match hlist_hashroot hl with
	  | Some h -> HHash(h)
	  | None -> raise (Failure("Impossible"))
	end
      else
	reduce_hlist_to_approx (List.filter (fun z -> not (z = h1)) al) hr

let save_ctree f tr =
  let ch = open_out_bin f in
  let c = seo_ctree seoc tr (ch,None) in
  seocf c;
  close_out ch

let save_octree f tr =
  let ch = open_out_bin f in
  let c = seo_option seo_ctree seoc tr (ch,None) in
  seocf c;
  close_out ch

let load_ctree f =
  let ch = open_in_bin f in
  let (tr,_) = sei_ctree seic (ch,None) in
  close_in ch;
  tr

let load_octree f =
  let ch = open_in_bin f in
  let (tr,_) = sei_option sei_ctree seic (ch,None) in
  close_in ch;
  tr

let remove_hashed_ctree r =
  let fn = Filename.concat !datadir (hashval_hexstring r) in
  if Sys.file_exists fn then Sys.remove fn

let ensure_dir_exists d =
  try
    let s = Unix.stat d in
    if not (s.Unix.st_kind = Unix.S_DIR) then
      raise (Failure (d ^ " is not a directory"))
  with
  | Unix.Unix_error(Unix.ENOENT,_,_) -> raise (Failure(d ^ " directory does not exist"))
  | _ -> raise (Failure("Problem with " ^ d))

let save_hashed_ctree r (tr:ctree) =
  ensure_dir_exists !datadir;
  let fn = Filename.concat !datadir (hashval_hexstring r) in
(*  Printf.printf "save_hashed_ctree %s %d\n" fn (ctree_numnodes tr); print_ctree tr; flush stdout; *)
  if not (Sys.file_exists fn) then
    begin
      let ch = open_out_gen [Open_wronly;Open_binary;Open_creat] 0o644 fn in
      let c = seo_ctree seoc tr (ch,None) in
      seocf c;
      close_out ch      
    end

let rec ctree_pre bl c d =
  match bl with
  | [] -> (Some(c),d)
  | (b::br) ->
      match c with
      | CLeaf(bl2,hl) -> if bl = bl2 then (Some(c),d) else (None,d)
      | CLeft(c0) -> if b then (None,d) else ctree_pre br c0 (d+1)
      | CRight(c1) -> if b then ctree_pre br c1 (d+1) else (None,d)
      | CBin(c0,c1) -> if b then ctree_pre br c1 (d+1) else ctree_pre br c0 (d+1)
      | _ ->
	  Printf.printf "ctree_pre Not_found\n"; flush stdout;
	  raise Not_found

let ctree_addr alpha c =
  ctree_pre (addr_bitseq alpha) c 0

let rec frame_filter_hlist i hl =
  if i > 0 then
    begin
      match hl with
      | HHash(h) -> HHash(h)
      | HNil -> HNil
      | HCons(a,hr) -> HCons(a,frame_filter_hlist (i-1) hr)
    end
  else
    match hlist_hashroot hl with
    | Some(h) -> HHash(h)
    | None -> HNil

let frame_filter_nehlist i hl =
  if i > 0 then
    begin
      match hl with
      | NehHash(h) -> NehHash(h)
      | NehCons(a,hr) -> NehCons(a,frame_filter_hlist (i-1) hr)
    end
  else
    NehHash(nehlist_hashroot hl)  

let rec frame_filter_leaf bl i c =
  match c with
  | CLeaf(bl2,hl) ->
      if bl = bl2 then
	begin
	  match i with
	  | Some(i) -> CLeaf(bl2,frame_filter_nehlist i hl)
	  | None -> c
	end
      else
	CLeaf(bl2,frame_filter_nehlist 0 hl)
  | CLeft(c0) ->
      begin
	match bl with
	| (false::br) -> frame_filter_leaf br i c0
	| (true::br) -> CLeft(CHash(ctree_hashroot c0))
	| [] -> raise (Failure "frame level problem")
      end
  | CRight(c1) ->
      begin
	match bl with
	| (false::br) -> CRight(CHash(ctree_hashroot c1))
	| (true::br) -> frame_filter_leaf br i c1
	| [] -> raise (Failure "frame level problem")
      end
  | CBin(c0,c1) ->
      begin
	match bl with
	| (false::br) -> CBin(frame_filter_leaf br i c0,CHash(ctree_hashroot c1))
	| (true::br) -> CBin(CHash(ctree_hashroot c0),frame_filter_leaf br i c1)
	| [] -> raise (Failure "frame level problem")
      end
  | _ -> c

let rec frame_hlist_bitseq f bl =
  match f with
  | FLeaf(bl2,i) -> if bl = bl2 then i else Some(0)
  | FAll -> None
  | FHash -> Some(0)
  | FAbbrev(fc) -> frame_hlist_bitseq fc bl
  | FBin(f0,f1) ->
      match bl with
      | (false::br) -> frame_hlist_bitseq f0 br
      | (true::br) -> frame_hlist_bitseq f1 br
      | [] -> raise (Failure "frame vs. leaf level problem")

let rec frame_filter_ctree f c =
  match f with
  | FHash -> CHash(ctree_hashroot c)
  | FAbbrev(fc) ->
      begin
	match c with
	| CAbbrev(hr,ha) -> CAbbrev(hr,ha)
	| _ ->
	    let c2 = frame_filter_ctree fc c in
	    let r2 = ctree_hashroot c2 in
	    let a2 = hashctree c2 in
	    save_hashed_ctree a2 c2;
	    CAbbrev(r2,a2)
      end
  | FAll -> c
  | FLeaf(bl,i) ->
      frame_filter_leaf bl i c
  | FBin(f0,f1) ->
      match c with
      | CLeft(c0) -> CLeft(frame_filter_ctree f0 c0)
      | CRight(c1) -> CRight(frame_filter_ctree f1 c1)
      | CBin(c0,c1) -> CBin(frame_filter_ctree f0 c0,frame_filter_ctree f1 c1)
      | CLeaf(false::bl,hl) -> (*** Leaves pass over FHash, but uses the FAbbrev to determine the abstraction to use for hl ***)
	  begin
	    match frame_hlist_bitseq f0 bl with
	    | Some(i) -> CLeaf(false::bl,frame_filter_nehlist i hl)
	    | None -> c
	  end
      | CLeaf(true::bl,hl) -> (*** Leaves pass over FHash, but uses the FAbbrev to determine the abstraction to use for hl ***)
	  begin
	    match frame_hlist_bitseq f1 bl with
	    | Some(i) -> CLeaf(true::bl,frame_filter_nehlist i hl)
	    | None -> c
	  end
      | CLeaf([],hl) -> raise (Failure "frame vs. ctree level problem")
      | _ ->
	  Printf.printf "FBin matched *strange ctree\n"; print_ctree c; flush stdout;
	  c

let frame_filter_octree fr oc =
  match oc with
  | Some(c) -> Some(frame_filter_ctree fr c)
  | None -> None

let get_ctree_abbrev h =
  ensure_dir_exists !datadir;
  let fn = Filename.concat !datadir (hashval_hexstring h) in
  if Sys.file_exists fn then
    begin
      let ch = open_in_bin fn in
      let (c,_) = sei_ctree seic (ch,None) in
      close_in ch;
      c
    end
  else
    raise (Failure ("could not resolve a needed ctree abbrev " ^ fn))

(*** archive_unused_ctrees/remove_unused_ctrees:
    c1 is the ctree at blockheight blkh and c2 is the ctree at blockheight blkh+1.
    Assume blkh+1 has been buried beneath 256 blocks and so is now being included
    as a rolling checkpoint. We can archive/delete subtrees of c1 which do not occur in c2.
    If archiving, put the hashes into 'archive' file along with the blockheight.
    Users can later call a command to actually move or delete the archived files at or up to some
    block height.
    If removing, then delete the files immediately.
 ***)
let add_to_archive ch blkh ha =
   seocf (seo_int64 seoc blkh (ch,None));
   seocf (seo_hashval seoc ha (ch,None))

let rec process_unused_ctrees_1 a c =
   match c with
   | CAbbrev(hr,ha) ->
     a ha;
     process_unused_ctrees_1 a (get_ctree_abbrev ha)
   | CLeft(cl) ->
     process_unused_ctrees_1 a cl
   | CRight(cr) ->
     process_unused_ctrees_1 a cr
   | CBin(cl,cr) ->
     process_unused_ctrees_1 a cl;
     process_unused_ctrees_1 a cr
   | _ -> ()

let rec process_unused_ctrees_2 a c1 c2 =
   match c1 with
   | CAbbrev(hr,ha) ->
      begin
        match c2 with
        | CAbbrev(hr2,ha2) when hr = hr2 && ha = ha2 -> ()
        | _ ->
          a ha;
          process_unused_ctrees_2 a (get_ctree_abbrev ha) c2
      end
   | CLeft(c1l) ->
     begin
       match c2 with
       | CAbbrev(hr,ha) -> process_unused_ctrees_2 a c1 (get_ctree_abbrev ha)
       | CLeft(c2l) -> process_unused_ctrees_2 a c1l c2l
       | CBin(c2l,c2r) -> process_unused_ctrees_2 a c1l c2l
       | CLeaf((b::bl),hl) when not b -> process_unused_ctrees_2 a c1l (CLeaf(bl,hl))
       | _ -> process_unused_ctrees_1 a c1l
     end
   | CRight(c1r) ->
     begin
       match c2 with
       | CAbbrev(hr,ha) -> process_unused_ctrees_2 a c1 (get_ctree_abbrev ha)
       | CRight(c2r) -> process_unused_ctrees_2 a c1r c2r
       | CBin(c2l,c2r) -> process_unused_ctrees_2 a c1r c2r
       | CLeaf((b::bl),hl) when b -> process_unused_ctrees_2 a c1r (CLeaf(bl,hl))
       | _ -> process_unused_ctrees_1 a c1r
     end
   | CBin(c1l,c1r) ->
     begin
       match c2 with
       | CAbbrev(hr,ha) -> process_unused_ctrees_2 a c1 (get_ctree_abbrev ha)
       | CLeft(c2l) ->
         process_unused_ctrees_2 a c1l c2l;
         process_unused_ctrees_1 a c1r
       | CRight(c2r) ->
         process_unused_ctrees_1 a c1l;
         process_unused_ctrees_2 a c1r c2r
       | CBin(c2l,c2r) ->
         process_unused_ctrees_2 a c1l c2l;
         process_unused_ctrees_2 a c1r c2r
       | CLeaf((b::bl),hl) when not b ->
         process_unused_ctrees_2 a c1l (CLeaf(bl,hl));
         process_unused_ctrees_1 a c1r
       | CLeaf((b::bl),hl) when b ->
         process_unused_ctrees_1 a c1l;
         process_unused_ctrees_2 a c1r (CLeaf(bl,hl))
       | _ ->
         process_unused_ctrees_1 a c1l;
         process_unused_ctrees_1 a c1r
     end
   | _ -> ()

let archive_unused_ctrees blkh c1 c2 =
  ensure_dir_exists !datadir;
  let fn = Filename.concat !datadir "archive" in
  if not (Sys.file_exists fn) then
    begin
      let ch = open_out_gen [Open_wronly;Open_binary;Open_creat] 0o644 fn in
      process_unused_ctrees_2 (add_to_archive ch blkh) c1 c2;
      close_out ch      
    end
  else
    begin
      let ch = open_out_gen [Open_wronly;Open_binary;Open_append] 0o644 fn in
      process_unused_ctrees_2 (add_to_archive ch blkh) c1 c2;
      close_out ch      
    end

let remove_unused_ctrees c1 c2 =
   process_unused_ctrees_2 remove_hashed_ctree c1 c2

let ctree_rights_balanced tr alpha ownr rtot1 rtot2 rtot3 outpl =
  match ownr with
  | Some(beta,None) -> (*** Owner does not allow right to use. Rights may have been obtained in the past. ***)
      Int64.add rtot1 rtot2 = rtot3
  | Some(beta,Some(r)) -> (*** Owner possibly requiring royalties (r = 0L if it is free to use) ***)
      if r > 0L then
	let rtot4 = Int64.div (units_sent_to_addr (payaddr_addr beta) outpl) r in
	Int64.add rtot1 rtot2 = Int64.add rtot3 rtot4
      else
	true (*** If it's free to use, people are free to use or create rights as they please. ***)
  | None -> false (*** No owner, in this case we shouldn't even be here ***)

let rec hlist_full_approx hl =
  match hl with
  | HHash(_) -> false
  | HNil -> true
  | HCons(a,hr) -> hlist_full_approx hr

let nehlist_full_approx hl =
  match hl with
  | NehHash(_) -> false
  | NehCons(a,hr) -> hlist_full_approx hr

let rec ctree_full_approx_addr tr bl =
  match tr with
  | CLeaf(br,hl) when br = bl -> nehlist_full_approx hl
  | CLeaf(_,_) -> true (*** fully approximates because we know it's empty ***)
  | CHash(_) -> false
  | CAbbrev(hr,ha) -> ctree_full_approx_addr (get_ctree_abbrev ha) bl
  | CLeft(trl) ->
      begin
	match bl with
	| (false::br) -> ctree_full_approx_addr trl br
	| _ -> true (*** fully approximates because we know it's empty ***)
      end
  | CRight(trr) ->
      begin
	match bl with
	| (true::br) -> ctree_full_approx_addr trr br
	| _ -> true (*** fully approximates because we know it's empty ***)
      end
  | CBin(trl,trr) ->
      begin
	match bl with
	| (false::br) -> ctree_full_approx_addr trl br
	| (true::br) -> ctree_full_approx_addr trr br
	| [] -> raise (Failure "Level problem") (*** should never happen ***)
      end

let rec ctree_supports_addr tr bl =
  match tr with
  | CLeaf(_,_) -> true
  | CHash(_) -> false
  | CAbbrev(hr,ha) -> ctree_supports_addr (get_ctree_abbrev ha) bl
  | CLeft(trl) ->
      begin
	match bl with
	| (false::br) -> ctree_supports_addr trl br
	| _ -> true (*** supports since known to be empty ***)
      end
  | CRight(trr) ->
      begin
	match bl with
	| (true::br) -> ctree_supports_addr trr br
	| _ -> true (*** supports since known to be empty ***)
      end
  | CBin(trl,trr) ->
      begin
	match bl with
	| (false::br) -> ctree_supports_addr trl br
	| (true::br) -> ctree_supports_addr trr br
	| [] -> raise (Failure "Level problem") (*** should never happen ***)
      end

let rec ctree_supports_asset a tr bl =
  match tr with
  | CLeaf(br,hl) when br = bl -> in_nehlist a hl
  | CLeaf(_,_) -> false
  | CHash(h) -> false
  | CAbbrev(hr,ha) -> ctree_supports_asset a (get_ctree_abbrev ha) bl
  | CLeft(trl) ->
      begin
	match bl with
	| (false::br) -> ctree_supports_asset a trl br
	| _ -> false
      end
  | CRight(trr) ->
      begin
	match bl with
	| (true::br) -> ctree_supports_asset a trr br
	| _ -> false
      end
  | CBin(trl,trr) ->
      begin
	match bl with
	| (false::br) -> ctree_supports_asset a trl br
	| (true::br) -> ctree_supports_asset a trr br
	| [] -> raise (Failure "Level problem") (*** should never happen ***)
      end

let rec ctree_lookup_asset k tr bl =
  match tr with
  | CLeaf(br,hl) when br = bl -> nehlist_lookup_asset k hl
  | CLeaf(_,_) -> None
  | CHash(h) -> None
  | CAbbrev(hr,ha) -> ctree_lookup_asset k (get_ctree_abbrev ha) bl
  | CLeft(trl) ->
      begin
	match bl with
	| (false::br) -> ctree_lookup_asset k trl br
	| _ -> None
      end
  | CRight(trr) ->
      begin
	match bl with
	| (true::br) -> ctree_lookup_asset k trr br
	| _ -> None
      end
  | CBin(trl,trr) ->
      begin
	match bl with
	| (false::br) -> ctree_lookup_asset k trl br
	| (true::br) -> ctree_lookup_asset k trr br
	| [] -> raise (Failure "Level problem") (*** should never happen ***)
      end

let rec ctree_lookup_addr_assets tr bl =
  match tr with
  | CLeaf(br,hl) when br = bl -> (nehlist_hlist hl)
  | CLeaf(_,_) -> HNil
  | CHash(h) -> HNil
  | CAbbrev(hr,ha) -> ctree_lookup_addr_assets (get_ctree_abbrev ha) bl
  | CLeft(trl) ->
      begin
	match bl with
	| (false::br) -> ctree_lookup_addr_assets trl br
	| _ -> HNil
      end
  | CRight(trr) ->
      begin
	match bl with
	| (true::br) -> ctree_lookup_addr_assets trr br
	| _ -> HNil
      end
  | CBin(trl,trr) ->
      begin
	match bl with
	| (false::br) -> ctree_lookup_addr_assets trl br
	| (true::br) -> ctree_lookup_addr_assets trr br
	| [] -> raise (Failure "Level problem") (*** should never happen ***)
      end

let rec ctree_lookup_marker tr bl =
  match tr with
  | CLeaf(br,hl) when br = bl -> nehlist_lookup_marker hl
  | CLeaf(_,_) -> None
  | CHash(h) -> None
  | CAbbrev(hr,ha) -> ctree_lookup_marker (get_ctree_abbrev ha) bl
  | CLeft(trl) ->
      begin
	match bl with
	| (false::br) -> ctree_lookup_marker trl br
	| _ -> None
      end
  | CRight(trr) ->
      begin
	match bl with
	| (true::br) -> ctree_lookup_marker trr br
	| _ -> None
      end
  | CBin(trl,trr) ->
      begin
	match bl with
	| (false::br) -> ctree_lookup_marker trl br
	| (true::br) -> ctree_lookup_marker trr br
	| [] -> raise (Failure "Level problem") (*** should never happen ***)
      end

exception NotSupported

let rec ctree_lookup_input_assets inpl tr =
  match inpl with
  | [] -> []
  | (alpha,k)::inpr ->
      match ctree_lookup_asset k tr (addr_bitseq alpha) with
      | Some(a) -> (alpha,a)::ctree_lookup_input_assets inpr tr
      | None -> raise NotSupported

let rec ctree_supports_output_addrs outpl tr =
  match outpl with
  | (alpha,_)::outpr ->
      if ctree_supports_addr tr (addr_bitseq alpha) then
	ctree_supports_output_addrs outpr tr
      else
	raise NotSupported
  | [] -> ()

(*** return the fee (negative) or reward (positive) if supports tx, otherwise raise NotSupported ***)
let ctree_supports_tx_2 tht sigt blkh tx aal al tr =
  let (inpl,outpl) = tx in
  ctree_supports_output_addrs outpl tr;
  let objaddrs = obj_rights_mentioned outpl in
  let propaddrs = prop_rights_mentioned outpl in
  let susesobjs = output_signaspec_uses_objs outpl in
  let susesprops = output_signaspec_uses_props outpl in
  let usesobjs = output_doc_uses_objs outpl in
  let usesprops = output_doc_uses_props outpl in
  let createsobjs = output_creates_objs outpl in
  let createsprops = output_creates_props outpl in
  let createsobjsaddrs1 = List.map (fun (th,h,k) -> hashval_term_addr h) createsobjs in
  let createspropsaddrs1 = List.map (fun (th,h) -> hashval_term_addr h) createsprops in
  let createsobjsaddrs2 = List.map (fun (th,h,k) -> hashval_term_addr (hashtag (hashopair2 th (hashpair h k)) 32l)) createsobjs in
  let createspropsaddrs2 = List.map (fun (th,h) -> hashval_term_addr (hashtag (hashopair2 th h) 33l)) createsprops in
  let createsnegpropsaddrs2 = List.map (fun (th,h) -> hashval_term_addr (hashtag (hashopair2 th h) 33l)) (output_creates_neg_props outpl) in
  (*** If an object or prop is included in a signaspec, then it must be royalty-free to use. ***)
  List.iter (fun (alphapure,alphathy) ->
    let hl = ctree_lookup_addr_assets tr (addr_bitseq (termaddr_addr alphapure)) in
    match hlist_lookup_obj_owner hl with
    | Some(_,Some(r)) when r = 0L ->
	begin
	  let hl = ctree_lookup_addr_assets tr (addr_bitseq (termaddr_addr alphathy)) in
	  match hlist_lookup_obj_owner hl with
	  | Some(_,Some(r)) when r = 0L -> ()
	  | _ -> raise NotSupported
	end
    | _ -> raise NotSupported
    )
    susesobjs;
  List.iter (fun (alphapure,alphathy) ->
    let hl = ctree_lookup_addr_assets tr (addr_bitseq (termaddr_addr alphapure)) in
    match hlist_lookup_prop_owner hl with
    | Some(_,Some(r)) when r = 0L ->
	begin
	  let hl = ctree_lookup_addr_assets tr (addr_bitseq (termaddr_addr alphathy)) in
	  match hlist_lookup_prop_owner hl with
	  | Some(_,Some(r)) when r = 0L -> ()
	  | _ -> raise NotSupported
	end
    | _ -> raise NotSupported
    )
    susesprops;
  (*** If rights are consumed in the input, then they must be mentioned in the output. ***)
  List.iter (fun a ->
    match a with
    | (_,_,_,RightsObj(beta,n)) ->
	if not (List.mem beta objaddrs) then
	  raise NotSupported
    | (_,_,_,RightsProp(beta,n)) ->
	if not (List.mem beta propaddrs) then
	  raise NotSupported
    | _ -> ()
	    )
    al;
  (*** ensure rights are balanced ***)
  List.iter (fun alpha ->
    let hl = ctree_lookup_addr_assets tr (addr_bitseq (termaddr_addr alpha)) in
    if hlist_full_approx hl &&
      ctree_rights_balanced tr alpha (hlist_lookup_obj_owner hl)
	(Int64.of_int (count_rights_used usesobjs alpha))
	(rights_out_obj outpl alpha)
	(count_obj_rights al alpha)
	outpl
    then
      ()
    else
      raise NotSupported)
    objaddrs;
  List.iter (fun alpha ->
    let hl = ctree_lookup_addr_assets tr (addr_bitseq (termaddr_addr alpha)) in
    if hlist_full_approx hl &&
      ctree_rights_balanced tr alpha (hlist_lookup_prop_owner hl)
	(Int64.of_int (count_rights_used usesprops alpha))
	(rights_out_prop outpl alpha)
	(count_prop_rights al alpha)
	outpl
    then
      ()
    else
      raise NotSupported)
    propaddrs;
  (*** publications are correct, new, and were declared in advance by placing a marker in the right pubaddr ***)
  let ensure_addr_empty alpha =
    match ctree_lookup_addr_assets tr (addr_bitseq alpha) with
    | HNil -> ()
    | _ -> raise NotSupported
  in
  List.iter
    (fun (alpha,(obl,u)) ->
      match u with
      | TheoryPublication(gamma,nonce,thy) ->
	  begin
	    ensure_addr_empty alpha; (*** make sure the publication is new because otherwise publishing it is pointless ***)
	    try
	      ignore (check_theoryspec thy);
	      let beta = hashval_pub_addr (hashpair (hashaddr (payaddr_addr gamma)) (hashpair nonce (hashtheoryspec thy))) in
	      ignore (List.find
			(fun a ->
			  match a with
			  | (h,bday,obl,Marker) -> List.mem (beta,h) inpl && Int64.add bday intention_minage <= blkh
			  | _ -> false
			)
			al)
	    with
	    | CheckingFailure -> raise NotSupported
	    | NonNormalTerm -> raise NotSupported
	    | Not_found -> raise NotSupported
	  end
      | SignaPublication(gamma,nonce,th,sl) ->
	  begin
	    ensure_addr_empty alpha; (*** make sure the publication is new because otherwise publishing it is pointless ***)
	    try
	      let gvtp th h a =
		let alpha = hashval_term_addr (hashtag (hashopair2 th (hashpair h (hashtp a))) 32l) in
		let hl = ctree_lookup_addr_assets tr (addr_bitseq alpha) in
		match hlist_lookup_obj_owner hl with
		| Some(beta,r) -> true
		| None -> false
	      in
	      let gvkn th k =
		let alpha = hashval_term_addr (hashtag (hashopair2 th k) 33l) in
		let hl = ctree_lookup_addr_assets tr (addr_bitseq alpha) in
		match hlist_lookup_prop_owner hl with (*** A proposition has been proven in a theory iff it has an owner. ***)
		| Some(beta,r) -> true
		| None -> false
	      in
	      let thy = ottree_lookup tht th in
	      ignore (check_signaspec gvtp gvkn th thy sigt sl);
	      let beta = hashval_pub_addr (hashpair (hashaddr (payaddr_addr gamma)) (hashpair nonce (hashopair2 th (hashsignaspec sl)))) in
	      ignore (List.find
			(fun a ->
			  match a with
			  | (h,bday,obl,Marker) -> List.mem (beta,h) inpl && Int64.add bday intention_minage <= blkh
			  | _ -> false
			)
			al)
	    with
	    | CheckingFailure -> raise NotSupported
	    | NonNormalTerm -> raise NotSupported
	    | Not_found -> raise NotSupported
	  end
      | DocPublication(gamma,nonce,th,dl) ->
	  begin
	    ensure_addr_empty alpha; (*** make sure the publication is new because otherwise publishing it is pointless ***)
	    try
	      let gvtp th h a =
		let alpha = hashval_term_addr (hashtag (hashopair2 th (hashpair h (hashtp a))) 32l) in
		let hl = ctree_lookup_addr_assets tr (addr_bitseq alpha) in
		match hlist_lookup_obj_owner hl with
		| Some(beta,r) -> true
		| None -> false
	      in
	      let gvkn th k =
		let alpha = hashval_term_addr (hashtag (hashopair2 th k) 33l) in
		let hl = ctree_lookup_addr_assets tr (addr_bitseq alpha) in
		match hlist_lookup_prop_owner hl with (*** A proposition has been proven in a theory iff it has an owner. ***)
		| Some(beta,r) -> true
		| None -> false
	      in
	      let thy = ottree_lookup tht th in
	      ignore (check_doc gvtp gvkn th thy sigt dl);
	      let beta = hashval_pub_addr (hashpair (hashaddr (payaddr_addr gamma)) (hashpair nonce (hashopair2 th (hashdoc dl)))) in
	      ignore (List.find
			(fun a ->
			  match a with
			  | (h,bday,obl,Marker) ->
			      List.mem (beta,h) inpl && Int64.add bday intention_minage <= blkh
			  | _ -> false
			)
			al)
	    with
	    | CheckingFailure -> raise NotSupported
	    | NonNormalTerm -> raise NotSupported
	    | Not_found -> raise NotSupported
	  end
      | _ -> ()
    )
    outpl;
  (*** If an ownership asset is spent in the input, then it must be included as an output.
       Once a termaddr is owned by someone, it must remain owned by someone. ***)
  List.iter
    (fun (alpha,(h,bday,obl,u)) ->
      match u with
      | OwnsObj(beta,r) ->
	  begin
	    try
	      ignore (List.find
			(fun (alpha2,(obl2,u2)) ->
			  alpha = alpha2 &&
			  match u2 with
			  | OwnsObj(beta2,r2) -> true
			  | _ -> false)
			outpl)
	    with Not_found -> raise NotSupported
	  end
      | OwnsProp(beta,r) ->
	  begin
	    try
	      ignore (List.find
			(fun (alpha2,(obl2,u2)) ->
			  alpha = alpha2 &&
			  match u2 with
			  | OwnsProp(beta2,r2) -> true
			  | _ -> false)
			outpl)
	    with Not_found -> raise NotSupported
	  end
      | OwnsNegProp ->
	  begin
	    try
	      ignore (List.find
			(fun (alpha2,(obl2,u2)) ->
			  alpha = alpha2 &&
			  match u2 with
			  | OwnsNegProp -> true
			  | _ -> false)
			outpl)
	    with Not_found -> raise NotSupported
	  end
      | _ -> ()
    )
    aal;
  (*** newly claimed ownership must be new and supported by a document in the tx, and must not be claimed more than once
       (Since the publisher of the document must sign the tx, the publisher agrees to this ownership declaration.)
       Also, ensure that each ownership asset has an explicit obligation for transfering it.
       The p2pkh or p2sh addr in this obligation is the owner in the sense of who can transfer it and who can collect bounties.
       The p2pkh or p2sh addr listed with the asset is the address which must be paid to buy rights to use the object or proposition.
   ***)
  let ownobjclaims = ref [] in
  let ownpropclaims = ref [] in
  let ownnegpropclaims = ref [] in
  List.iter
    (fun (alpha,(obl,u)) ->
      match u with
      | OwnsObj(beta,r) ->
	  begin
	    try
	      ignore
		(List.find
		   (fun (alpha1,(_,_,_,u1)) ->
		     alpha = alpha1 &&
		     match u1 with
		     | OwnsObj(_,_) -> true
		     | _ -> false)
		   aal); (*** if the ownership is being transferred ***)
	      ownobjclaims := alpha::!ownobjclaims;
	    with Not_found ->
	      (*** if the ownership is being created ***)
	      if (List.mem alpha createsobjsaddrs1 || List.mem alpha createsobjsaddrs2) && not (List.mem alpha !ownobjclaims) then
		let hl = ctree_lookup_addr_assets tr (addr_bitseq alpha) in
		begin
		  ownobjclaims := alpha::!ownobjclaims;
		  match hlist_lookup_obj_owner hl with
		  | Some(beta2,r2) -> raise NotSupported (*** already owned ***)
		  | None ->
		      match obl with (*** insist on an obligation, or the ownership will not be transferable; also don't allow it to be indicated as a reward ***)
		      | Some(_,_,b) when not b -> ()
		      | _ -> raise NotSupported
		end
	      else
		raise NotSupported
	  end
      | OwnsProp(beta,r) -> 
	  begin
	    try
	      ignore
		(List.find
		   (fun (alpha1,(_,_,_,u1)) ->
		     alpha = alpha1 &&
		     match u1 with
		     | OwnsProp(beta1,r1) -> true
		     | _ -> false)
		   aal); (*** if the ownership is being transferred ***)
	      ownpropclaims := alpha::!ownpropclaims;
	    with Not_found ->
	      (*** if the ownership is being created ***)
	      if (List.mem alpha createspropsaddrs1 || List.mem alpha createspropsaddrs2) && not (List.mem alpha !ownpropclaims) then
		let hl = ctree_lookup_addr_assets tr (addr_bitseq alpha) in
		begin
		  ownpropclaims := alpha::!ownpropclaims;
		  match hlist_lookup_prop_owner hl with
		  | Some(beta2,r2) -> raise NotSupported (*** already owned ***)
		  | None ->
		      match obl with (*** insist on an obligation, or the ownership will not be transferable; note that a trivial transfer is made to collect bounties ***)
		      | Some(_,_,b) when not b -> ()
		      | _ -> raise NotSupported
		end
	      else
		raise NotSupported
	  end
      | OwnsNegProp -> 
	  begin
	    try
	      ignore (List.find (fun (alpha1,(_,_,_,u1)) -> u1 = OwnsNegProp && alpha = alpha1) aal); (*** if the ownership is being transferred ***)
	      ownnegpropclaims := alpha::!ownnegpropclaims;
	    with Not_found ->
	      (*** if the ownership is being created ***)
	      if (List.mem alpha createsnegpropsaddrs2) && not (List.mem alpha !ownnegpropclaims) then
		let hl = ctree_lookup_addr_assets tr (addr_bitseq alpha) in
		begin
		  ownpropclaims := alpha::!ownpropclaims;
		  if hlist_lookup_neg_prop_owner hl then
		    raise NotSupported (*** already owned ***)
		  else
		    match obl with (*** insist on an obligation, or the ownership will not be transferable; note that a trivial transfer is made to collect bounties ***)
		    | Some(_,_,b) when not b -> ()
		    | _ -> raise NotSupported
		end
	      else
		raise NotSupported
	  end
      | _ -> ()
    )
    outpl;
  (***
      new objects and props must be given ownership by the tx publishing the document.
   ***)
  List.iter (fun (th,tmh,tph) ->
    try
      let ensureowned alpha =
	let hl = ctree_lookup_addr_assets tr (addr_bitseq alpha) in
	match hlist_lookup_obj_owner hl with
	| Some(beta2,r2) -> () (*** already owned ***)
	| None -> (*** Since alpha was listed in full_needed we know alpha really isn't owned here ***)
	    (*** ensure that it will be owned after the tx ***)
	    if not (List.mem alpha !ownobjclaims) then
	      raise Not_found
      in
      let alphapure = hashval_term_addr tmh in
      let alphathy = hashval_term_addr (hashtag (hashopair2 th (hashpair tmh tph)) 32l) in
      ensureowned alphapure;
      ensureowned alphathy
    with Not_found -> raise NotSupported
    )
    createsobjs;
  List.iter (fun (th,tmh) ->
    try
      let ensureowned alpha =
	let hl = ctree_lookup_addr_assets tr (addr_bitseq alpha) in
	match hlist_lookup_prop_owner hl with
	| Some(beta2,r2) -> () (*** already owned ***)
	| None -> (*** Since alpha was listed in full_needed we know alpha really isn't owned here ***)
	    (*** ensure that it will be owned after the tx ***)
	    if not (List.mem alpha !ownpropclaims) then
	      raise Not_found
      in
      let alphapure = hashval_term_addr tmh in
      let alphathy = hashval_term_addr (hashtag (hashopair2 th tmh) 33l) in
      ensureowned alphapure;
      ensureowned alphathy
    with Not_found -> raise NotSupported
    )
    createsprops;
  (*** bounties can be collected by the owners of props or negprops
       To make checking this easy, the ownership asset is spent and recreated unchanged (except the asset id).
       Note that address for the relevant signature is in the obligation of the ownership asset.
       Essentially the ownership gets trivially transfered when the bounty is collected.
       Someone can place bounties on pure propositions, but this is a bad idea.
       Someone else could collect it by creating an inconsistent theory and giving a trivial proof.
       Real bounties should only be placed on propositions within a theory.
   ***)
  List.iter
    (fun (alpha,(h,bday,obl,u)) -> 
      match u with
      | Bounty(v) ->
	  begin
	    try
	      (*** ensure that an owner of the prop or negprop signed the tx because the ownership asset was an input value ***)
	      ignore
		(List.find
		   (fun (alpha2,(h2,bday2,obl2,u2)) -> (*** remember: it's the obligation that determines who signs these; so the obligations tells who the "owners" are for the purpose of collecting bounties ***)
		     alpha = alpha2 &&
		     match u2 with
		     | OwnsProp(beta2,r2) -> true
		     | OwnsNegProp -> true
		     | _ -> false
		   )
		   aal)
	    with Not_found -> raise NotSupported
	  end
      | _ -> ()
    )
    aal;
  (*** finally, return the number of currency units created or destroyed ***)
  Int64.sub (out_cost outpl) (asset_value_sum al)

let ctree_supports_tx tht sigt blkh tx tr =
  let (inpl,outpl) = tx in
  let aal = ctree_lookup_input_assets inpl tr in
  let al = List.map (fun (_,a) -> a) aal in
  ctree_supports_tx_2 tht sigt blkh tx aal al tr

let rec hlist_lub hl1 hl2 =
  match hl1 with
  | HNil -> HNil
  | HHash(_) -> hl2
  | HCons(h1,hr1) ->
      match hl2 with
      | HNil -> raise (Failure "incompatible hlists")
      | HHash(_) -> hl1
      | HCons(_,hr2) -> HCons(h1,hlist_lub hr1 hr2)

let nehlist_lub hl1 hl2 =
  match hl1 with
  | NehHash(_) -> hl2
  | NehCons(h1,hr1) ->
      match hl2 with
      | NehHash(_) -> hl1
      | NehCons(_,hr2) -> NehCons(h1,hlist_lub hr1 hr2)

let rec ctreeLinv c =
  match c with
  | CLeaf(bl,hl) -> Some(bl,hl)
  | CLeft(c0) ->
      begin
	match ctreeLinv c0 with
	| Some(bl,hl) -> Some(false::bl,hl)
	| None -> None
      end
  | CRight(c1) ->
      begin
	match ctreeLinv c1 with
	| Some(bl,hl) -> Some(true::bl,hl)
	| None -> None
      end
  | _ -> None

let rec ctree_singlebranch_lub bl hl c =
  match ctreeLinv c with
  | Some(_,hl2) -> CLeaf(bl,nehlist_lub hl hl2)
  | None -> CLeaf(bl,hl)

let rec ctree_lub c1 c2 =
  match c1 with
  | CHash(_) -> c2
  | CAbbrev(hr,ha) -> ctree_lub (get_ctree_abbrev ha) c2
  | CLeaf(bl1,hl1) -> ctree_singlebranch_lub bl1 hl1 c2
  | CLeft(c10) ->
      begin
	match c2 with
	| CHash(_) -> c1
	| CAbbrev(hr,ha) -> ctree_lub c1 (get_ctree_abbrev ha)
	| CLeaf(bl2,hl2) -> ctree_singlebranch_lub bl2 hl2 c1
	| CLeft(c20) -> CLeft (ctree_lub c10 c20)
	| _ -> raise (Failure "no lub for incompatible ctrees")
      end
  | CRight(c11) ->
      begin
	match c2 with
	| CHash(_) -> c1
	| CAbbrev(hr,ha) -> ctree_lub c1 (get_ctree_abbrev ha)
	| CLeaf(bl2,hl2) -> ctree_singlebranch_lub bl2 hl2 c1
	| CRight(c21) -> CRight (ctree_lub c11 c21)
	| _ -> raise (Failure "no lub for incompatible ctrees")
      end
  | CBin(c10,c11) ->
      begin
	match c2 with
	| CHash(_) -> c1
	| CAbbrev(hr,ha) -> ctree_lub c1 (get_ctree_abbrev ha)
	| CBin(c20,c21) -> CBin(ctree_lub c10 c20,ctree_lub c11 c21)
	| _ -> raise (Failure "no lub for incompatible ctrees")
      end

let octree_lub oc1 oc2 =
  match (oc1,oc2) with
  | (Some(c1),Some(c2)) ->
      Some(ctree_lub c1 c2)
  | (None,None) -> None
  | _ -> raise (Failure "no lub for incompatible octrees")

let rec hlist_reduce_to_min_support aidl hl =
  match aidl with
  | [] ->
      begin
	match hlist_hashroot hl with
	| Some(h) -> HHash(h)
	| None -> HNil
      end
  | _ ->
      begin
	match hl with
	| HCons((h,bh,o,u),hr) ->
	    HCons((h,bh,o,u),hlist_reduce_to_min_support (List.filter (fun z -> not (z = h)) aidl) hr)
	| _ -> hl
      end

let rec ctree_reduce_to_min_support n inpl outpl full c =
  if n > 0 then
    begin
      if inpl = [] && outpl = [] && full = [] then
	CHash(ctree_hashroot c)
      else
	begin
	  match c with
	  | CLeaf(false::bl,hl) ->
	      begin
		match ctree_reduce_to_min_support (n-1)
		      (strip_bitseq_false inpl)
		      (strip_bitseq_false0 outpl)
		      (strip_bitseq_false0 full)
		      (CLeaf(bl,hl))
		with
		| CLeaf(bl2,hl2) -> CLeaf(false::bl2,hl2)
		| c2 -> CLeft(c2)
	      end
	  | CLeaf(true::bl,hl) ->
	      begin
		match ctree_reduce_to_min_support (n-1)
		      (strip_bitseq_true inpl)
		      (strip_bitseq_true0 outpl)
		      (strip_bitseq_true0 full)
		      (CLeaf(bl,hl))
		with
		| CLeaf(bl2,hl2) -> CLeaf(true::bl2,hl2)
		| c2 -> CRight(c2)
	      end
	  | CLeft(c0) ->
	      CLeft(ctree_reduce_to_min_support (n-1)
		      (strip_bitseq_false inpl)
		      (strip_bitseq_false0 outpl)
		      (strip_bitseq_false0 full)
		      c0)
	  | CRight(c1) ->
	      CRight(ctree_reduce_to_min_support (n-1)
		       (strip_bitseq_true inpl)
		       (strip_bitseq_true0 outpl)
		       (strip_bitseq_true0 full)
		       c1)
	  | CBin(c0,c1) ->
	      CBin(ctree_reduce_to_min_support (n-1)
		     (strip_bitseq_false inpl)
		     (strip_bitseq_false0 outpl)
		     (strip_bitseq_false0 full)
		     c0,
		   ctree_reduce_to_min_support (n-1)
		       (strip_bitseq_true inpl)
		       (strip_bitseq_true0 outpl)
		       (strip_bitseq_true0 full)
		       c1)
	  | CAbbrev(hr,ha) ->
	      ctree_reduce_to_min_support n inpl outpl full (get_ctree_abbrev ha)
	  | CHash(h) -> (*** If we reach this point, the ctree does not support the tx, contrary to assumption. ***)
	      raise (Failure("ctree does not support the tx"))
	  | _ -> c
	end
    end
  else if full = [] then
    begin
      match c with
      | CLeaf([],NehHash(_)) -> c
      | CLeaf([],(NehCons((h,bh,o,u),hr) as hl)) ->
	  if inpl = [] then
	    CLeaf([],NehHash(nehlist_hashroot hl))
	  else
	    CLeaf([],NehCons((h,bh,o,u),hlist_reduce_to_min_support (List.filter (fun z -> not (z = h)) (List.map (fun (_,k) -> k) inpl)) hr))
      | _ -> raise (Failure "impossible")
    end
  else (*** At this point we are necessarily at a leaf. However, if the full hlist is not here, then it will not be fully supported. Not checking since we assume c supported before calling reduce_to_min. ***)
    c

let octree_reduce_to_min_support inpl outpl full oc =
  match oc with
  | None -> None
  | Some(c) -> Some (ctree_reduce_to_min_support 162 inpl outpl full c)

let rec full_needed_1 outpl =
  match outpl with
  | [] -> []
  | (_,(o,(RightsObj(beta,_))))::outpr -> addr_bitseq (termaddr_addr beta)::full_needed_1 outpr
  | (_,(o,(RightsProp(beta,_))))::outpr -> addr_bitseq (termaddr_addr beta)::full_needed_1 outpr
  | (alpha,(o,(OwnsObj(_,_))))::outpr -> addr_bitseq alpha::full_needed_1 outpr
  | (alpha,(o,(OwnsProp(_,_))))::outpr -> addr_bitseq alpha::full_needed_1 outpr
  | (_,(o,TheoryPublication(gamma,nonce,thy)))::outpr ->
      let beta = hashval_pub_addr (hashpair (hashaddr (payaddr_addr gamma)) (hashpair nonce (hashtheoryspec thy))) in
      addr_bitseq beta::full_needed_1 outpr
  | (_,(o,SignaPublication(gamma,nonce,th,sl)))::outpr ->
      let beta = hashval_pub_addr (hashpair (hashaddr (payaddr_addr gamma)) (hashpair nonce (hashopair2 th (hashsignaspec sl)))) in
      List.map (fun h -> addr_bitseq (hashval_term_addr h)) (signaspec_stp_markers th sl)
      @ List.map (fun h -> addr_bitseq (hashval_term_addr h)) (signaspec_known_markers th sl)
      @ addr_bitseq beta::full_needed_1 outpr
  | (_,(o,DocPublication(gamma,nonce,th,dl)))::outpr ->
      let beta = hashval_pub_addr (hashpair (hashaddr (payaddr_addr gamma)) (hashpair nonce (hashopair2 th (hashdoc dl)))) in
      List.map (fun h -> addr_bitseq (hashval_term_addr h)) (doc_stp_markers th dl)
      @ List.map (fun h -> addr_bitseq (hashval_term_addr h)) (doc_known_markers th dl)
      @ addr_bitseq beta::full_needed_1 outpr
  | _::outpr -> full_needed_1 outpr

let full_needed outpl =
  let r = ref (full_needed_1 outpl) in
  List.iter
    (fun (alphapure,alphathy) ->
	r := addr_bitseq (hashval_term_addr alphapure)::addr_bitseq (hashval_term_addr alphathy)::!r)
    (output_doc_uses_objs outpl);
  List.iter
    (fun (alphapure,alphathy) ->
	r := addr_bitseq (hashval_term_addr alphapure)::addr_bitseq (hashval_term_addr alphathy)::!r)
    (output_doc_uses_props outpl);
  !r

let get_tx_supporting_octree (inpl,outpl) oc =
  octree_reduce_to_min_support
    (List.map (fun (alpha,z) -> (addr_bitseq alpha,z)) inpl)
    (List.map (fun (alpha,(_,_)) -> addr_bitseq alpha) outpl)
    (full_needed outpl)
    oc

let rec get_txl_supporting_octree txl oc =
  match txl with
  | (tx::txr) ->
      octree_lub (get_tx_supporting_octree tx oc) (get_txl_supporting_octree txr oc)
  | [] -> 
      match oc with
      | Some(c) -> Some(CHash(ctree_hashroot c))
      | None -> None

