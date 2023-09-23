// ignore_for_file: avoid_function_literals_in_foreach_calls, non_constant_identifier_names, unnecessary_import, prefer_const_constructors


import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_app/Models/Like%20User%20Model.dart';
import 'package:social_app/Models/Comment%20User%20Model.dart';
import 'package:social_app/Models/Message%20Model.dart';
import 'package:social_app/Models/Post%20Model.dart';
import 'package:social_app/Models/User%20Model.dart';
import 'package:social_app/Screens/Layout%20Screens/ChatsScreen.dart';
import 'package:social_app/Screens/Layout%20Screens/HomeScreen.dart';
import 'package:social_app/Screens/Layout%20Screens/SettingsScreen.dart';
import 'package:social_app/Screens/homeLayout.dart';
import 'package:social_app/Screens/loginScreen.dart';
import 'package:social_app/Shared/CacheHelper.dart';
import 'package:social_app/Shared/Components.dart';
import 'package:social_app/Shared/Variables%20and%20Constants.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

part 'app_state.dart';

class AppCubit extends Cubit<AppState> {
  AppCubit() : super(AppInitial());

  static AppCubit get(BuildContext context) => BlocProvider.of(context);

  UserModel? model;
  var scaffoldKey = GlobalKey<ScaffoldState>();
  late String profilePictureUrl;
  late String coverPictureUrl;
  String postPicUrl="";
  late String email;
  var commentController = TextEditingController();


  final fireStore = FirebaseFirestore.instance;
  final fireStorage = FirebaseStorage.instance;

   void hello() {
    print("object");
   }

  void getUser() {
    fireStore.collection("Users").doc(uId).get().then((value) {
      model = UserModel.fromJson(value.data());
      profilePictureUrl=model!.profilePicture;
      coverPictureUrl=model!.coverPicture;
      email=model!.email;
      emit(successUserState());
    }).catchError((error) {
      emit(failedUserState(error.toString()));
    });
  }

  List<postModel> posts =[];
  List<String> postsId=[];
  Map<String,List<LikeUserModel>> likes ={};
  Map<String,List<CommentUserModel>> comments ={};


  void getPosts() {
    List<postModel> tempPosts =[];
    List<String> TemppostsId=[];
    tempPosts =[];
    TemppostsId=[];
    emit(loadingPostsState());
    fireStore
    .collection("Posts")
    .get()
    .then((value) {
      emit(loadingPostsState());
        value.docs.forEach((element5) async {
          tempPosts.add(postModel.fromJson(element5.data()));
          TemppostsId.add(element5.id);
          Future.wait(
            [
              getLikes(element: element5),
              getComments(element: element5)
            ]
          ).then((value) {
            posts=tempPosts;
            postsId=TemppostsId;
          })
          .whenComplete(() {
            emit(successPostsState());
          });
      });
    })
    .catchError((error) {
      emit(failedPostsState(error.toString()));
    });
  }

  List<Widget> screens = [
    HomeScreen(),
    const ChatsScreen(),
    const SettingsScreen(),
  ];


  Future<void> getLikes(
    {required QueryDocumentSnapshot<Map<String, dynamic>> element}
  ) async {
          await element
          .reference
          .collection("Likes")
          .get()
          .then((value) {
            List<LikeUserModel> tempLlist=[];
            value.docs.forEach((element1) {
            tempLlist.add(LikeUserModel.fromJson(element1.data()));
          });
          likes[element.id]=tempLlist;
          });
  }

  Future<void> getComments({
    required QueryDocumentSnapshot<Map<String, dynamic>> element
  }) async {
    await element
          .reference
          .collection("Comments")
          .get()
          .then((value) {
            List<CommentUserModel> tempClist=[];
            value.docs.forEach((element2) {
              tempClist.add(CommentUserModel.fromJson(element2.data()));
            });
            comments[element.id]=tempClist;
        });
  }


  List<UserModel> chats=[];

  void getChats() {
    emit(loadingGetChatsState());
    List<UserModel> tempChats=[];
    fireStore
    .collection("Users")
    .get()
    .then((value) {
      value.docs.forEach((element) {
        if (element.id!=uId){
          tempChats.add(UserModel.fromJson(element.data()));
        }
      });
    })
    .whenComplete(() {
      chats=tempChats;
      emit(successGetChatsState());
    })
    .catchError((error) {
      emit(failedGetChatsState());
    });
  }

  void sendMessage({
    required String reciever_uId,
    required String message,
  }) {
      http.get(Uri.parse('http://worldtimeapi.org/api/ip'))
      .then((value) {
        var data = json.decode(value.body);
        var dateTime = DateTime.parse(data['datetime']);

        MessageModel model = MessageModel(
      text: message, 
      recieverUId: reciever_uId, 
      senderUId: uId!, 
      dateTime: dateTime.toString());
    fireStore
    .collection("Users")
    .doc(uId)
    .collection("Chats")
    .doc(reciever_uId)
    .collection("Messages")
    .add(model.toJson())
    .then((value) {
      emit(successSendMessageState());
    })
    .catchError((error) {
      emit(failedSendMessageState());
    });
    fireStore
    .collection("Users")
    .doc(reciever_uId)
    .collection("Chats")
    .doc(uId)
    .collection("Messages")
    .add(model.toJson())
    .then((value) {
      emit(successSendMessageState());
    })
    .catchError((error) {
      emit(failedSendMessageState());
    });

      });
  }

  List<MessageModel> messages = [];
  bool nomessages=false;

  void getMessages(String reciever_uId) {
    fireStore
    .collection("Users")
    .doc(uId)
    .collection("Chats")
    .doc(reciever_uId)
    .collection("Messages")
    .orderBy("dateTime")
    .snapshots()
    .listen((event) {
      nomessages=false;
      messages=[];
      event.docs.forEach((element) {
        messages.add(MessageModel.fromJson(element.data()));
      });
      nomessages=true;
      emit(successgetMessageState());
    });
  }


  void likePost({
    required String postId,
  }) {
    fireStore
    .collection("Posts")
    .doc(postId)
    .collection("Likes")
    .get()
    .then((value) {
      bool something=false;
      for (var element in value.docs) { 
        if (element.id == uId) {
          something=true;
          break;
        }
      }
      if (!something) {
      fireStore
      .collection("Posts")
      .doc(postId)
      .collection("Likes")
      .doc(uId)
      .set({
        "name" : model!.name,
        "profilePic" : model!.profilePicture,
      })
      .then((value) {
        getPosts();
        emit(likePostState());
      })
      .catchError((error) {
        emit(failedLikePostState());
      });
      } else {
        fireStore
      .collection("Posts")
      .doc(postId)
      .collection("Likes")
      .doc(uId)
      .delete()
      .then((value) {
        getPosts();
        emit(likePostState());
        
      })
      .catchError((error) {
        emit(failedLikePostState());
      });
      }
    });
  }

  bool commentAdding=false;

  void addComment({ 
    required String postId,
    required BuildContext context
  }) {
    commentAdding=true;
    fireStore
    .collection("Posts")
    .doc(postId)
    .collection("Comments")
    .add({
      "name" : model!.name,
      "profilePic" : model!.profilePicture,
      "text":commentController.text
    })
    .then((value) {
      Navigator.pop(context);
      commentAdding=false;
      commentController.text='';
      emit(successUploadCommentState());
      getPosts();
    })
    .catchError((error) {
      emit(failedUploadCommentState());
    });
  }

  int currentIndex=0; 

  void changeBottomBarIndex(int i) {
    currentIndex = i;
    emit(changeBottomNaviagationBar());
  }

  void SignOut(BuildContext context) {
    FirebaseAuth.instance.signOut().then((value) {
      cacheHelper.deleteData(key: "uId");
      navigateToAndErase(context: context, destination: LoginScreen());
    });
  }

  final ImagePicker picker = ImagePicker();

  File? profilePic;

  bool update=true;

  void changeProfilePicture() {
    picker.pickImage(source: ImageSource.gallery).then((value) {
      profilePic=File(value!.path);
      update=false;
      emit(loadingChangeProfilePictureState());
      fireStorage
      .ref()
      .child("Users/$uId/Profiles/${Uri.file(value.path).pathSegments.last}")
      .putFile(profilePic!)
      .then((value) {
        update=true;
        emit(changeProfilePictureState());
        value.ref.getDownloadURL().then((value) {profilePictureUrl=value;});
    })
    .catchError((error) {
      update=true;
      error.toString();
    });
    });
  }

  File? coverPic;

  void changeCoverPicture() async {
    picker.pickImage(source: ImageSource.gallery).then((value) {
      coverPic=File(value!.path);
      update=false;
      emit(loadingChangeCoverPictureState());
      fireStorage
      .ref()
      .child("Users/$uId/Cover/${Uri.file(value.path).pathSegments.last}")
      .putFile(coverPic!)
      .then((value) {
        update=true;
      emit(changeCoverPictureState());
      value.ref.getDownloadURL().then((value) {coverPictureUrl=value;});
    });
    }).catchError((error) {
      update=true;
      emit(failedChangeCoverPictureState());
    });
  }

  File? postPic;

  void choosePostImage() async {
    picker.pickImage(source: ImageSource.gallery).then((value) {
      postPic=File(value!.path);
      emit(changePostPictureState());
    }).catchError((error) {
      emit(failedChangePostPictureState());
    });
  }

  void uploadPostImage({
    required String text,
    required BuildContext context
  }) {
    emit(loadingUploadPostPicState());
    fireStorage
    .ref()
    .child("Posts/$uId/${Uri.file(postPic!.path).pathSegments.last}")
    .putFile(postPic!)
    .then((value) {
      value.ref.getDownloadURL().then((value) {
        postPicUrl=value;
        uploadPost(text: text,context: context);
        });
    })
    .catchError((error) {
    });
  }

  void deletePostPic() {
    postPic=null;
    emit(postPicDeletedState());
  }

  void uploadPost({
    required BuildContext context,
    required String text,
  }) {
    emit(loadingUploadPostState());
    var now = DateTime.now();
    var temp_post_model = postModel(
      name: model!.name,
      profilePic: model!.profilePicture,
      text: text,
      postPic: postPicUrl,
      dateTime: now.toString()
      ); 
    fireStore
    .collection("Posts")
    .add(temp_post_model.toJson())
    .then((value) {
      emit(successUploadPostState());
      getPosts();
      navigateToAndErase(context: context, destination: const HomeLayout());
    })
    .catchError((error) {
      emit(failedUploadPostState());
    });
  }


  void updateUser({
    required String bio,
    required String name,
    required String phone,
    required String email,
    required String uId,
    required BuildContext context
  }) {
    var temp_model = UserModel(name: name, email: email, phone: phone, uId: uId, bio: bio, coverPicture: coverPictureUrl, profilePicture: profilePictureUrl);
    emit(loadingUserState());

    fireStore
    .collection("Users")
    .doc(uId)
    .update(temp_model.toJson())
    .then((value) {
      navigateToAndErase(context: context, destination: HomeLayout());
      model=null;
      getUser();
    })
    .catchError((error) {
      emit(failedUpdateState());
    });
  
  }
}
