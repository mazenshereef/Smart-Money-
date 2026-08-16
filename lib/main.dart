import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const appName = 'Smart Money';
const creatorEmail = 'mazenshereef.ads@gmail.com';

class Tx {
  String id, name, type;
  double amount;
  Tx({required this.id, required this.name, required this.amount, required this.type});
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'amount':amount,'type':type};
  factory Tx.fromJson(Map<String,dynamic> j)=>Tx(
    id: j['id'] ?? '', name: j['name'] ?? '', amount: (j['amount'] as num).toDouble(), type: j['type'] ?? 'Cash In');
}

class Note {
  String id,title,date;
  List<Tx> transactions;
  Note({required this.id,required this.title,required this.date,required this.transactions});
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'createdDate':date,'transactions':transactions.map((e)=>e.toJson()).toList()};
  factory Note.fromJson(Map<String,dynamic> j)=>Note(
    id:j['id']??'', title:j['title']??'', date:j['createdDate']??'',
    transactions:(j['transactions'] as List? ?? []).map((e)=>Tx.fromJson(Map<String,dynamic>.from(e))).toList());
}

class AppState extends ChangeNotifier {
  final prefs = SharedPreferencesAsync();
  List<Note> notes=[];
  String profile='';
  String password='';
  bool dark=false, unlocked=false, ready=false;
  Note? selected;
  String screen='home';

  Future<void> load() async {
    final p = await prefs.getString('smart_password');
    password=p??'';
    profile=await prefs.getString('smart_profile')??'';
    dark=await prefs.getBool('smart_dark')??false;
    final raw=await prefs.getString('smart_notes');
    if(raw!=null){ try { notes=(jsonDecode(raw) as List).map((e)=>Note.fromJson(Map<String,dynamic>.from(e))).toList(); } catch(_){ } }
    ready=true; notifyListeners();
  }
  Future<void> save() async {
    await prefs.setString('smart_notes', jsonEncode(notes.map((e)=>e.toJson()).toList()));
    notifyListeners();
  }
  Future<void> setDark(bool v) async { dark=v; await prefs.setBool('smart_dark',v); notifyListeners(); }
  Future<void> setProfile(String v) async { profile=v; await prefs.setString('smart_profile',v); notifyListeners(); }
  Future<void> setPassword(String v) async { password=v; await prefs.setString('smart_password',v); unlocked=true; notifyListeners(); }
  void go(String s){screen=s;notifyListeners();}
  void addNote(String title){
    final n=Note(id:DateTime.now().microsecondsSinceEpoch.toString(),title:title.trim(),
      date:MaterialLocalizations.of(navigatorKey.currentContext!).formatMedium(DateTime.now()),transactions:[]);
    notes.insert(0,n); selected=n; screen='note'; save();
  }
  void deleteSelected(){if(selected==null)return;notes.removeWhere((n)=>n.id==selected!.id);selected=null;screen='home';save();}
  void addTx(String name,double amount,String type,{String? editId}){
    if(selected==null)return;
    if(editId!=null){
      final i=selected!.transactions.indexWhere((x)=>x.id==editId);
      if(i>=0) selected!.transactions[i]=Tx(id:editId,name:name,amount:amount,type:type);
    }else{
      selected!.transactions.add(Tx(id:DateTime.now().microsecondsSinceEpoch.toString(),name:name,amount:amount,type:type));
    }
    screen='note'; save();
  }
  void deleteTx(String id){selected?.transactions.removeWhere((x)=>x.id==id);save();}
  void editNote(String title){if(selected!=null){selected!.title=title;screen='note';save();}}
  double total(String type)=>selected?.transactions.where((x)=>x.type==type).fold(0.0,(a,b)=>a+b.amount)??0;
}
final navigatorKey=GlobalKey<NavigatorState>();

void main()=>runApp(const SmartMoneyApp());

class SmartMoneyApp extends StatefulWidget{
  const SmartMoneyApp({super.key});
  State<SmartMoneyApp> createState()=>_SmartMoneyAppState();
}
class _SmartMoneyAppState extends State<SmartMoneyApp>{
  final s=AppState();
  @override void initState(){super.initState();s.addListener((){if(mounted)setState((){});});s.load();}
  @override Widget build(BuildContext context){
    final theme=ThemeData(useMaterial3:true,brightness:s.dark?Brightness.dark:Brightness.light,
      scaffoldBackgroundColor:s.dark?const Color(0xff111111):const Color(0xffF7F7F5),
      colorSchemeSeed:Colors.grey);
    return MaterialApp(navigatorKey:navigatorKey,debugShowCheckedModeBanner:false,title:appName,theme:theme,
      home:!s.ready?const Scaffold(body:Center(child:CircularProgressIndicator())):
      s.password.isNotEmpty&&!s.unlocked?PasswordPage(s:s):ScreenRouter(s:s));
  }
}

class ScreenRouter extends StatelessWidget{
  final AppState s; const ScreenRouter({super.key,required this.s});
  Widget build(BuildContext c){
    switch(s.screen){
      case 'create': return FormPage(s:s,title:'New Transaction Note',label:'Note Title',button:'Create',
        initial:'',onSave:(v){if(v.trim().isNotEmpty)s.addNote(v);});
      case 'note': return NotePage(s:s);
      case 'cashin': return TxPage(s:s,type:'Cash In');
      case 'cashout': return TxPage(s:s,type:'Cash Out');
      case 'editnote': return FormPage(s:s,title:'Edit Note',label:'Note Title',button:'Save Changes',
        initial:s.selected?.title??'',onSave:(v){if(v.trim().isNotEmpty)s.editNote(v);});
      case 'settings': return SettingsPage(s:s);
      case 'profile': return ProfilePage(s:s);
      case 'chatbot': return ChatPage(s:s);
      case 'about': return AboutPage(s:s);
      case 'contact': return ContactPage(s:s);
      default: return HomePage(s:s);
    }
  }
}

class PasswordPage extends StatefulWidget{final AppState s;const PasswordPage({super.key,required this.s});State<PasswordPage> createState()=>_PasswordPageState();}
class _PasswordPageState extends State<PasswordPage>{
  final a=TextEditingController(),b=TextEditingController(); bool show=false;
  Widget build(BuildContext c)=>Scaffold(body:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(28),child:ConstrainedBox(
    constraints:const BoxConstraints(maxWidth:430),child:Column(children:[
      Icon(Icons.account_balance_wallet_outlined,size:70),const SizedBox(height:18),
      const Text(appName,style:TextStyle(fontSize:32,fontWeight:FontWeight.w900)),const SizedBox(height:8),
      Text('Welcome Back',style:TextStyle(color:Theme.of(c).colorScheme.onSurfaceVariant)),const SizedBox(height:32),
      TextField(controller:a,obscureText:!show,decoration:InputDecoration(labelText:'Enter Your Password',prefixIcon:const Icon(Icons.lock_outline),suffixIcon:IconButton(icon:Icon(Icons.visibility),onPressed:()=>setState(()=>show=!show)),border:OutlineInputBorder(borderRadius:BorderRadius.circular(16)))),
      const SizedBox(height:14),
      FilledButton.icon(onPressed:(){if(a.text==widget.s.password){widget.s.unlocked=true;widget.s.notifyListeners();}else{_msg(c,'Incorrect Password');}},icon:const Icon(Icons.lock_open),label:const Text('Unlock Smart Money'),style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(54))),
    ])) )));
}
void _msg(BuildContext c,String x)=>ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text(x)));

class HomePage extends StatelessWidget{
  final AppState s;const HomePage({super.key,required this.s});
  Widget build(BuildContext c)=>Scaffold(
    bottomNavigationBar:SafeArea(child:Padding(padding:const EdgeInsets.all(14),child:FilledButton.icon(
      onPressed:()=>s.go('create'),icon:const Icon(Icons.add),label:const Text('Add Transaction Note'),style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(52))))),
    body:SafeArea(child:Row(children:[
      NavigationRail(selectedIndex:0,onDestinationSelected:(i){if(i==1)s.go('settings');if(i==2)s.go('profile');if(i==3)s.go('about');if(i==4)s.go('contact');},
        labelType:NavigationRailLabelType.none,destinations:const[
          NavigationRailDestination(icon:Icon(Icons.account_balance_wallet_outlined),label:Text('Home')),
          NavigationRailDestination(icon:Icon(Icons.settings_outlined),label:Text('Settings')),
          NavigationRailDestination(icon:Icon(Icons.person_outline),label:Text('Profile')),
          NavigationRailDestination(icon:Icon(Icons.info_outline),label:Text('About')),
          NavigationRailDestination(icon:Icon(Icons.mail_outline),label:Text('Contact')),
        ]),
      Expanded(child:Padding(padding:const EdgeInsets.fromLTRB(18,25,18,10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text(appName,style:TextStyle(fontSize:29,fontWeight:FontWeight.w800)),
        const SizedBox(height:4),Text('Your Money , Organized .',style:TextStyle(color:Colors.grey)),const SizedBox(height:20),
        Expanded(child:s.notes.isEmpty?const Center(child:Text('No Transaction Notes Yet',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold))):
        ListView.builder(itemCount:s.notes.length,itemBuilder:(c,i){final n=s.notes[i];return Card(
          child:ListTile(contentPadding:const EdgeInsets.all(16),title:Text(n.title,style:const TextStyle(fontWeight:FontWeight.w700)),
            subtitle:Text('${n.transactions.length} Transaction${n.transactions.length==1?'':'s'}'),
            trailing:Text(n.date),onTap:(){s.selected=n;s.go('note');}));}))
      ])))
    ])));
}

class FormPage extends StatefulWidget{final AppState s;final String title,label,button,initial;final void Function(String) onSave;const FormPage({super.key,required this.s,required this.title,required this.label,required this.button,required this.initial,required this.onSave});State<FormPage> createState()=>_FormPageState();}
class _FormPageState extends State<FormPage>{late TextEditingController x;void initState(){super.initState();x=TextEditingController(text:widget.initial);}
Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(widget.title)),body:Padding(padding:const EdgeInsets.all(22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
Text(widget.label),const SizedBox(height:8),TextField(controller:x,decoration:const InputDecoration(border:OutlineInputBorder(),hintText:'Example : House Expenses')),
const SizedBox(height:22),Row(children:[Expanded(child:OutlinedButton(onPressed:()=>widget.s.go(widget.title.startsWith('Edit')?'note':'home'),child:const Text('Cancel'))),const SizedBox(width:12),Expanded(child:FilledButton(onPressed:()=>widget.onSave(x.text),child:Text(widget.button)))])
])));
}

class NotePage extends StatelessWidget{
 final AppState s;const NotePage({super.key,required this.s});
 Widget build(BuildContext c){final n=s.selected!;final cin=s.total('Cash In'),cout=s.total('Cash Out');return Scaffold(
 appBar:AppBar(title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(n.title),Text(n.date,style:const TextStyle(fontSize:12))]),actions:[
 IconButton(icon:const Icon(Icons.edit_outlined),onPressed:(){s.go('editnote');}),IconButton(icon:const Icon(Icons.delete_outline,color:Colors.red),onPressed:s.deleteSelected)]),
 body:Column(children:[
 Padding(padding:const EdgeInsets.all(15),child:Row(children:[Expanded(child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:const Color(0xff3C6B46)),onPressed:()=>s.go('cashin'),icon:const Icon(Icons.arrow_downward),label:const Text('Cash In'))),const SizedBox(width:12),Expanded(child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:const Color(0xff8A4545)),onPressed:()=>s.go('cashout'),icon:const Icon(Icons.arrow_upward),label:const Text('Cash Out')))])),
 Expanded(child:n.transactions.isEmpty?const Center(child:Text('No Transactions Yet')):ListView.builder(padding:const EdgeInsets.symmetric(horizontal:15),itemCount:n.transactions.length,itemBuilder:(c,i){final t=n.transactions[i];return Card(child:ListTile(
 title:Text(t.name,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${_money(t.amount)} EGP'),
 trailing:Row(mainAxisSize:MainAxisSize.min,children:[Chip(label:Text(t.type.toUpperCase(),style:const TextStyle(fontSize:9))),IconButton(icon:const Icon(Icons.edit_outlined),onPressed:(){_openEditTx(c,s,t);}),IconButton(icon:const Icon(Icons.delete_outline,color:Colors.red),onPressed:()=>s.deleteTx(t.id))])));})),
 Card(margin:const EdgeInsets.all(15),child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[
 _sum('Cash In',cin),_sum('Cash Out',cout),_sum('Difference',cin-cout,bold:true)])))
 ]);}
 Widget _sum(String a,double b,{bool bold=false})=>Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(a),Text('${_money(b)} EGP',style:TextStyle(fontWeight:bold?FontWeight.w900:FontWeight.w700,fontSize:bold?16:14))]));
}
Future<void> _openEditTx(BuildContext c,AppState s,Tx t) async {
 final n=TextEditingController(text:t.name), a=TextEditingController(text:t.amount.toString());
 await showDialog(context:c,builder:(d)=>AlertDialog(title:Text('Edit ${t.type}'),content:Column(mainAxisSize:MainAxisSize.min,children:[
 TextField(controller:n,decoration:const InputDecoration(labelText:'Transaction Name')),TextField(controller:a,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Amount'))]),
 actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),FilledButton(onPressed:(){final v=double.tryParse(a.text.replaceAll(',',''));if(v!=null&&v>0){s.addTx(n.text,v,t.type,editId:t.id);Navigator.pop(d);}},child:const Text('Save'))]));
}

class TxPage extends StatefulWidget{final AppState s;final String type;const TxPage({super.key,required this.s,required this.type});State<TxPage> createState()=>_TxPageState();}
class _TxPageState extends State<TxPage>{final n=TextEditingController(),a=TextEditingController();
Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(widget.type)),body:Padding(padding:const EdgeInsets.all(22),child:Column(children:[
TextField(controller:n,decoration:const InputDecoration(labelText:'Transaction Name',border:OutlineInputBorder())),
const SizedBox(height:18),TextField(controller:a,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Amount',border:OutlineInputBorder())),
const SizedBox(height:22),Row(children:[Expanded(child:OutlinedButton(onPressed:()=>widget.s.go('note'),child:const Text('Cancel'))),const SizedBox(width:12),Expanded(child:FilledButton(onPressed:(){final v=double.tryParse(a.text.replaceAll(',',''));if(n.text.trim().isEmpty||v==null||v<=0){_msg(c,'Enter a valid name and amount');return;}widget.s.addTx(n.text.trim(),v,widget.type);},child:const Text('Save')))])
]));}

class SettingsPage extends StatefulWidget{final AppState s;const SettingsPage({super.key,required this.s});State<SettingsPage> createState()=>_SettingsPageState();}
class _SettingsPageState extends State<SettingsPage>{
 final cur=TextEditingController(),nw=TextEditingController(),cf=TextEditingController();
 Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Settings')),body:ListView(padding:const EdgeInsets.all(22),children:[
 ListTile(title:const Text('Password Protection'),trailing:Text(widget.s.password.isEmpty?'Off':'Always On')),
 ListTile(title:const Text('Change Password'),trailing:const Icon(Icons.chevron_right),onTap:()=>showDialog(context:c,builder:(d)=>AlertDialog(title:const Text('Change Password'),content:Column(mainAxisSize:MainAxisSize.min,children:[
 TextField(controller:cur,obscureText:true,decoration:const InputDecoration(labelText:'Current Password')),TextField(controller:nw,obscureText:true,decoration:const InputDecoration(labelText:'New Password')),TextField(controller:cf,obscureText:true,decoration:const InputDecoration(labelText:'Confirm New Password'))]),
 actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancel')),FilledButton(onPressed:(){if(cur.text!=widget.s.password){_msg(c,'Current password is incorrect');return;}if(nw.text.length<4||nw.text!=cf.text){_msg(c,'Check the new password');return;}widget.s.setPassword(nw.text);Navigator.pop(d);},child:const Text('Confirm'))]))),
 SwitchListTile(title:const Text('Theme Mode'),subtitle:Text(widget.s.dark?'Dark':'Light'),value:widget.s.dark,onChanged:widget.s.setDark),
 ListTile(title:const Text('Account Profile'),trailing:const Icon(Icons.chevron_right),onTap:()=>widget.s.go('profile')),
 ListTile(title:const Text('Smart Money Assistant'),trailing:const Icon(Icons.chevron_right),onTap:()=>widget.s.go('chatbot')),
 ]));
}

class ProfilePage extends StatefulWidget{final AppState s;const ProfilePage({super.key,required this.s});State<ProfilePage> createState()=>_ProfilePageState();}
class _ProfilePageState extends State<ProfilePage>{late TextEditingController n;void initState(){super.initState();n=TextEditingController(text:widget.s.profile);}
Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Profile')),body:ListView(padding:const EdgeInsets.all(18),children:[
 CircleAvatar(radius:46,child:Text(n.text.isEmpty?'S':n.text.trim()[0].toUpperCase(),style:const TextStyle(fontSize:38,fontWeight:FontWeight.w900))),
 const SizedBox(height:14),Center(child:Text(n.text.isEmpty?'Smart Money User':n.text,style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900))),
 const SizedBox(height:25),Card(child:Padding(padding:const EdgeInsets.all(18),child:TextField(controller:n,decoration:const InputDecoration(labelText:'Name',prefixIcon:Icon(Icons.person_outline))))),
 const SizedBox(height:12),FilledButton.icon(onPressed:(){widget.s.setProfile(n.text);_msg(c,'Profile Saved');},icon:const Icon(Icons.check_circle_outline),label:const Text('Save Profile')),
 Card(child:const ListTile(leading:Icon(Icons.shield_outlined),title:Text('Account Security'),subtitle:Text('Your Smart Money Account Is Protected .'))),
 Card(child:const ListTile(leading:Icon(Icons.phone_android_outlined),title:Text('Local Account'),subtitle:Text('Your Profile Information Is Stored On This Device .'))),
 ]));}

class ChatPage extends StatefulWidget{final AppState s;const ChatPage({super.key,required this.s});State<ChatPage> createState()=>_ChatPageState();}
class _ChatPageState extends State<ChatPage>{final q=TextEditingController();String ans='';
String answer(String x){final z=x.toLowerCase();if(z.contains('cash in'))return'Cash In Means Money That You Received .';if(z.contains('cash out'))return'Cash Out Means Money That You Paid .';if(z.contains('difference'))return'Difference Is Calculated By Subtracting Cash Out From Cash In .';if(z.contains('delete'))return'You Can Delete A Transaction Using The Small Delete Button Next To It .';if(z.contains('note'))return'A Note Keeps A Group Of Transactions Together .';if(z.contains('smart money'))return'Smart Money Helps You Organize Money You Receive And Money You Pay .';return'I Am Here To Help You Understand Your Money And Your Smart Money Notes .';}
Widget build(BuildContext c){final qs=['What Is Cash In ?','What Is Cash Out ?','How Is Difference Calculated ?','How Do I Delete A Transaction ?','What Is A Note ?','What Is Smart Money ?'];return Scaffold(appBar:AppBar(title:const Text('Smart Money Assistant')),body:ListView(padding:const EdgeInsets.all(22),children:[
const Center(child:Icon(Icons.chat_bubble_outline,size:50)),const SizedBox(height:20),...qs.map((x)=>Card(child:ListTile(title:Text(x),trailing:const Icon(Icons.chevron_right),onTap:()=>setState(()=>ans=answer(x))))),
TextField(controller:q,decoration:const InputDecoration(labelText:'Ask Something About Smart Money',border:OutlineInputBorder())),const SizedBox(height:12),
FilledButton(onPressed:()=>setState(()=>ans=answer(q.text)),child:const Text('Ask Assistant')),if(ans.isNotEmpty)Card(margin:const EdgeInsets.only(top:20),child:Padding(padding:const EdgeInsets.all(18),child:Text(ans)))
]));}}

class AboutPage extends StatelessWidget{final AppState s;const AboutPage({super.key,required this.s});Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('About')),body:ListView(padding:const EdgeInsets.all(22),children:[
const Center(child:Icon(Icons.account_balance_wallet_outlined,size:65)),const Center(child:Text(appName,style:TextStyle(fontSize:29,fontWeight:FontWeight.w900))),const Center(child:Text('Version 1 . 0')),const SizedBox(height:25),
const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('Smart Money Is A Simple And Professional Personal Money Management Application Designed To Help You Organize Your Daily Financial Transactions With Clarity And Ease .\n\nThe Application Allows You To Create Independent Transaction Notes , Record Money You Receive As Cash In , Record Money You Pay As Cash Out , And Automatically Calculate The Difference Between Them .\n\nEvery Note Is Independent . Money From One Note Is Never Carried Into Another Note .\n\nSmart Money Was Designed With A Clean Interface , Simple Navigation , And Reliable Local Data Storage .')))
]));}

class ContactPage extends StatelessWidget{final AppState s;const ContactPage({super.key,required this.s});Future<void> mail(BuildContext c)async{final u=Uri(scheme:'mailto',path:creatorEmail,query:'subject=Smart Money - Contact&body=Hello,\\n\\nI would like to contact the creator of Smart Money.');if(!await launchUrl(u,mode:LaunchMode.externalApplication))_msg(c,'Unable To Open Email');}
Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Contact Creator')),body:Padding(padding:const EdgeInsets.all(22),child:Column(children:[
const Icon(Icons.mail_outline,size:65),const SizedBox(height:15),const Text('Have A Question , Suggestion , Or Found A Problem ? Send An Email Directly To The Creator Of Smart Money .',textAlign:TextAlign.center),const SizedBox(height:25),
FilledButton.icon(onPressed:()=>mail(c),icon:const Icon(Icons.mail_outline),label:const Text('Send Email To Creator')),const SizedBox(height:18),Text(creatorEmail,style:const TextStyle(color:Colors.grey))
])));}
String _money(double x)=>x.toStringAsFixed(x.truncateToDouble()==x?0:2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(_)=>',');
