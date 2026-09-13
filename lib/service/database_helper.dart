import 'dart:io';

import 'package:loanx/model/family_relation.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/model/loan_change.dart';
import 'package:loanx/model/mortgage_material.dart';
import 'package:loanx/model/weight_unit.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
// import 'package:faker/faker.dart';
import '../db/fastdb.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'loanx.db');
    if (await File(path).exists()) {
      return await openDatabase(
        path,
        version: 7,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
        password: 'yourhgjgujjhjhjhsecure_passwordhfjffffhgf',
      );
    }
    return await openDatabase(
      path,
      version: 7,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
      password: 'yourhgjgujjhjhjhsecure_passwordhfjffffhgf',
    );
  }

  Future onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(
        db,
        'loans',
        'completedBy TEXT NOT NULL DEFAULT \'\'',
      );
      await _addColumnIfMissing(db, 'loans', 'settlementAmount REAL');
      await _addColumnIfMissing(
        db,
        'loans',
        'completionReference TEXT NOT NULL DEFAULT \'\'',
      );
      await _addColumnIfMissing(
        db,
        'loans',
        'completionNotes TEXT NOT NULL DEFAULT \'\'',
      );
    }
    if (oldVersion < 3) {
      await _createLoanChangesTable(db);
    }
    if (oldVersion < 4) {
      await _addColumnIfMissing(
        db,
        'loans',
        'lockInDays INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'loans',
        'earlyRedemptionCharge REAL NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 5) {
      await _addColumnIfMissing(
        db,
        'loans',
        'mortgageTermYears INTEGER NOT NULL DEFAULT 5',
      );
    }
    if (oldVersion < 6) {
      await _addColumnIfMissing(
        db,
        'loans',
        "weightUnit TEXT NOT NULL DEFAULT 'g'",
      );
      await _createWeightUnitsTable(db);
      await _insertDefaultWeightUnits(db);
    }
    if (oldVersion < 7) {
      await _addColumnIfMissing(
        db,
        'loans',
        "termsAndConditions TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  Future<void> _createWeightUnitsTable(Database db) =>
      db.execute('''CREATE TABLE IF NOT EXISTS ${WeightUnit.tableName}(
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      symbol TEXT NOT NULL UNIQUE,
      isAddedByUser INTEGER NOT NULL DEFAULT 0
    )''');

  Future<void> _insertDefaultWeightUnits(DatabaseExecutor db) async {
    for (final unit in const [
      WeightUnit(name: 'Gram', symbol: 'g'),
      WeightUnit(name: 'Kilogram', symbol: 'kg'),
      WeightUnit(name: 'Milligram', symbol: 'mg'),
      WeightUnit(name: 'Tola', symbol: 'tola'),
    ]) {
      await db.insert(
        WeightUnit.tableName,
        unit.toJson(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _createLoanChangesTable(Database db) =>
      db.execute('''CREATE TABLE IF NOT EXISTS ${LoanChange.tableName}(
      id INTEGER PRIMARY KEY,
      loanId INTEGER NOT NULL,
      description TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      FOREIGN KEY (loanId) REFERENCES loans (id)
    )''');

  Future<void> _addColumnIfMissing(
    Database db,
    String tableName,
    String columnDefinition,
  ) async {
    final columnName = columnDefinition.split(' ').first;
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final columnExists = columns.any((column) => column['name'] == columnName);

    if (!columnExists) {
      await db.execute('ALTER TABLE $tableName ADD COLUMN $columnDefinition');
    }
  }

  Future onCreate(Database db, int version) async {
    // List<String> indianBoysNames = [
    //   "Aarav Sharma",
    //   "Ayaan Verma",
    //   "Aditya Singh",
    //   "Arjun Patel",
    //   "Amir Reddy",
    //   "Aryan Sharma",
    //   "Aakash Verma",
    //   "Amit Singh",
    //   "Ankit Patel",
    //   "Anil Reddy",
    //   "Bhavesh Sharma",
    //   "Bharat Verma",
    //   "Bhuvan Singh",
    //   "Brahma Patel",
    //   "Brijesh Reddy",
    //   "Bhavin Sharma",
    //   "Bhaskar Verma",
    //   "Bipin Singh",
    //   "Bhuvnesh Patel",
    //   "Balraj Reddy",
    //   "Chirag Sharma",
    //   "Chetan Verma",
    //   "Chandan Singh",
    //   "Charan Patel",
    //   "Chintu Reddy",
    //   "Chetan Sharma",
    //   "Chirayu Verma",
    //   "Chaitanya Singh",
    //   "Chandra Patel",
    //   "Chinmay Reddy",
    //   "Dev Sharma",
    //   "Darshan Verma",
    //   "Daksh Singh",
    //   "Dhruv Patel",
    //   "Dinesh Reddy",
    //   "Deepak Sharma",
    //   "Dilip Verma",
    //   "Durga Singh",
    //   "Dhiren Patel",
    //   "Divyesh Reddy",
    //   "Ekansh Sharma",
    //   "Eshaan Verma",
    //   "Eklavya Singh",
    //   "Eshan Patel",
    //   "Ekansh Reddy",
    //   "Eshwar Sharma",
    //   "Eli Verma",
    //   "Eshant Singh",
    //   "Eswar Patel",
    //   "Ekavir Reddy",
    //   "Faiz Sharma",
    //   "Farhan Verma",
    //   "Firoz Singh",
    //   "Fahad Patel",
    //   "Feroz Reddy",
    //   "Faraz Sharma",
    //   "Faisal Verma",
    //   "Farid Singh",
    //   "Fanish Patel",
    //   "Farhan Reddy",
    //   "Gaurav Sharma",
    //   "Girish Verma",
    //   "Ganesh Singh",
    //   "Gautam Patel",
    //   "Gopal Reddy",
    //   "Girish Sharma",
    //   "Govind Verma",
    //   "Gurpreet Singh",
    //   "Gundeep Patel",
    //   "Gaurish Reddy",
    //   "Hitesh Sharma",
    //   "Harsh Verma",
    //   "Harish Singh",
    //   "Himanshu Patel",
    //   "Hiren Reddy",
    //   "Harshad Sharma",
    //   "Hemant Verma",
    //   "Himmat Singh",
    //   "Harinder Patel",
    //   "Hriday Reddy",
    //   "Ishan Sharma",
    //   "Indrajit Verma",
    //   "Ishwar Singh",
    //   "Iqbal Patel",
    //   "Inder Reddy",
    //   "Irshad Sharma",
    //   "Ikshan Verma",
    //   "Imran Singh",
    //   "Iqraam Patel",
    //   "Ishaan Reddy",
    //   "Jatin Sharma",
    //   "Jagdish Verma",
    //   "Jai Singh",
    //   "Jaspal Patel",
    //   "Jayesh Reddy",
    //   "Jaswant Sharma",
    //   "Jitendra Verma",
    //   "Jeevan Singh",
    //   "Jignesh Patel",
    //   "Jaspreet Reddy",
    //   "Karan Sharma",
    //   "Kunal Verma",
    //   "Kishore Singh",
    //   "Kartik Patel",
    //   "Krishna Reddy",
    //   "Kapil Sharma",
    //   "Kushal Verma",
    //   "Kailash Singh",
    //   "Kiran Patel",
    //   "Keshav Reddy",
    //   "Lakshman Sharma",
    //   "Lalit Verma",
    //   "Lokesh Singh",
    //   "Laxman Patel",
    //   "Lakshay Reddy",
    //   "Lavanya Sharma",
    //   "Luv Verma",
    //   "Laxmi Singh",
    //   "Lohit Patel",
    //   "Lokendra Reddy",
    //   "Mohan Sharma",
    //   "Manoj Verma",
    //   "Mukesh Singh",
    //   "Mithun Patel",
    //   "Mudit Reddy",
    //   "Mohit Sharma",
    //   "Mehul Verma",
    //   "Mayank Singh",
    //   "Madhav Patel",
    //   "Mahesh Reddy",
    //   "Nikhil Sharma",
    //   "Nitin Verma",
    //   "Naveen Singh",
    //   "Niraj Patel",
    //   "Nilesh Reddy",
    //   "Nirav Sharma",
    //   "Naresh Verma",
    //   "Navin Singh",
    //   "Nagesh Patel",
    //   "Naman Reddy",
    //   "Omkar Sharma",
    //   "Onkar Verma",
    //   "Ojas Singh",
    //   "Omkara Patel",
    //   "Om Reddy",
    //   "Ojaswin Sharma",
    //   "Ojasya Verma",
    //   "Ojaswit Singh",
    //   "Oja Patel",
    //   "Ojasvat Reddy",
    //   "Pranav Sharma",
    //   "Pankaj Verma",
    //   "Prashant Singh",
    //   "Parth Patel",
    //   "Pradeep Reddy",
    //   "Piyush Sharma",
    //   "Punit Verma",
    //   "Pavan Singh",
    //   "Prithvi Patel",
    //   "Prem Reddy",
    //   "Rajesh Sharma",
    //   "Rahul Verma",
    //   "Ravi Singh",
    //   "Rakesh Patel",
    //   "Rohit Reddy",
    //   "Raj Sharma",
    //   "Raman Verma",
    //   "Ranjit Singh",
    //   "Raghav Patel",
    //   "Rajendra Reddy",
    //   "Suresh Sharma",
    //   "Saurabh Verma",
    //   "Sanjay Singh",
    //   "Siddharth Patel",
    //   "Sandeep Reddy",
    //   "Sunil Sharma",
    //   "Suraj Verma",
    //   "Suhas Singh",
    //   "Samir Patel",
    //   "Saket Reddy",
    //   "Tarun Sharma",
    //   "Tejas Verma",
    //   "Tushar Singh",
    //   "Tanmay Patel",
    //   "Tapan Reddy",
    //   "Tulsi Sharma",
    //   "Tariq Verma",
    //   "Tarak Singh",
    //   "Tarakesh Patel",
    //   "Tarunesh Reddy",
    //   "Umesh Sharma",
    //   "Uday Verma",
    //   "Utkarsh Singh",
    //   "Udit Patel",
    //   "Ujwal Reddy",
    //   "Upendra Sharma",
    //   "Ujjwal Verma",
    //   "Umang Singh",
    //   "Utpal Patel",
    //   "Umeshwar Reddy",
    //   "Vikram Sharma",
    //   "Vishal Verma",
    //   "Varun Singh",
    //   "Vivek Patel",
    //   "Vikas Reddy",
    //   "Vinay Sharma",
    //   "Vishnu Verma",
    //   "Vikrant Singh",
    //   "Vijay Patel",
    //   "Vaibhav Reddy",
    //   "Yogesh Sharma",
    //   "Yash Verma",
    //   "Yuvraj Singh",
    //   "Yogendra Patel",
    //   "Yog Reddy",
    //   "Yug Sharma",
    //   "Yudhishthir Verma",
    //   "Yuv Singh",
    //   "Yashwanth Patel",
    //   "Yatin Reddy",
    //   "Zain Sharma",
    //   "Zahid Verma",
    //   "Zubair Singh",
    //   "Zeeshan Patel",
    //   "Zeeshaan Reddy",
    //   "Zaman Sharma",
    //   "Zoravar Verma",
    //   "Zainul Singh",
    //   "Zainuddin Patel",
    //   "Zakwan Reddy",
    //   "Aarav Singh",
    //   "Aryan Sharma",
    //   "Aditya Patel",
    //   "Arjun Reddy",
    //   "Vivaan Verma",
    //   "Ansh Raj",
    //   "Dhruv Mehta",
    //   "Ayaan Khanna",
    //   "Sai Kapoor",
    //   "Rohan Shah",
    //   "Vihaan Bhatia",
    //   "Krishna Rao",
    //   "Ishaan Gupta",
    //   "Shaan Malik",
    //   "Dev Sharma",
    //   "Arnav Sinha",
    //   "Kabir Joshi",
    //   "Arush Das",
    //   "Tanmay Mishra",
    //   "Samarth Roy",
    //   "Kushal Yadav",
    //   "Aarush Jain",
    //   "Nirvaan Bhardwaj",
    //   "Ritvik Singh",
    //   "Ved Saxena",
    //   "Moksh Arora",
    //   "Pranav Kaur",
    //   "Shaan Bhagat",
    //   "Yash Sehgal",
    //   "Veer Kapoor",
    //   "Atharv Chauhan",
    //   "Aayush Kulkarni",
    //   "Akash Desai",
    //   "Rishabh Deshmukh",
    //   "Shivansh Naidu",
    //   "Aryan Thakur",
    //   "Rudra Nair",
    //   "Parth Sengupta",
    //   "Arav Agarwal",
    //   "Shaurya Rao",
    //   "Ishaan Banerjee",
    //   "Tanishq Mahajan",
    //   "Pratyush Batra",
    //   "Vedant Sethi",
    //   "Divit Chadha",
    //   "Krishna Bhatt",
    //   "Manan Chauhan",
    //   "Anay Malhotra",
    //   "Atharva Rathi",
    //   "Hriday Sharma",
    //   "Daksh Tiwari",
    //   "Harsh Kapoor",
    //   "Rudransh Vora",
    //   "Aaditya Singhania",
    //   "Arijit Kohli",
    //   "Shiv Bansal",
    //   "Siddharth Ghosh",
    //   "Yuvraj Garg",
    //   "Hrithik Chawla",
    //   "Ayaan Saxena",
    //   "Anshul Sood",
    //   "Laksh Mehta",
    //   "Angad Ahuja",
    //   "Aarvin Joshi",
    //   "Arnav Mittal",
    //   "Manav Kapoor",
    //   "Ayush Gupta",
    //   "Aryan Shah",
    //   "Vivaan Patel",
    //   "Vihaan Kumar",
    //   "Kabir Malhotra",
    //   "Aaryan Sharma",
    //   "Rudra Singh",
    //   "Shreyas Patel",
    //   "Devansh Gupta",
    //   "Ishaan Verma",
    //   "Nirvaan Mehta",
    //   "Hrishikesh Roy",
    //   "Vivaan Kapoor",
    //   "Advik Chandra",
    //   "Arhaan Khanna",
    //   "Samar Shah",
    //   "Tanish Chauhan",
    //   "Ritvik Nair",
    //   "Kiaan Rao",
    //   "Shaurya Sinha",
    //   "Aryan Joshi",
    //   "Aarush Kulkarni",
    //   "Pranav Das",
    //   "Ved Saxena",
    //   "Ayaan Pandey",
    //   "Atharv Bhardwaj",
    //   "Darsh Bajaj",
    //   "Rihan Thakur",
    //   "Aaditya Shetty",
    //   "Krish Raj",
    //   "Harshvardhan Batra",
    //   "Rishaan Agarwal",
    //   "Anay Dutta",
    //   "Aarav Rao",
    //   "Manan Iyer",
    //   "Laksh Sehgal",
    //   "Riaan Kohli",
    //   "Aarav Kapoor",
    //   "Arush Ghosh",
    //   "Vihaan Bhagat",
    //   "Nirvaan Deshmukh",
    //   "Prithvi Naidu",
    //   "Shivansh Banerjee",
    //   "Shaan Mahajan",
    //   "Atharva Joshi",
    //   "Advait Jain",
    //   "Aarav Rathi",
    //   "Aryan Bansal",
    //   "Hriday Sood",
    //   "Samar Garg",
    //   "Aarvin Malhotra",
    //   "Ayaan Chawla",
    //   "Krish Sethi",
    //   "Dev Sharma",
    //   "Vivaan Reddy",
    //   "Shaan Kapoor",
    //   "Tanay Desai",
    //   "Yuvraj Gupta",
    //   "Vihaan Roy",
    //   "Kian Patel",
    //   "Arnav Rao",
    //   "Ishaan Thakur",
    //   "Aaryan Joshi",
    //   "Raghav Kumar",
    //   "Samarth Batra",
    //   "Tanmay Mehta",
    //   "Pranav Sinha",
    //   "Aayush Kapoor",
    //   "Kabir Raj",
    //   "Arjun Dutta",
    //   "Aarav Singh",
    //   "Atharv Verma",
    //   "Ritvik Bajaj",
    //   "Aryan Gupta",
    //   "Ayaan Bhardwaj",
    //   "Vivaan Shah",
    //   "Kush Rao",
    //   "Manan Naidu",
    //   "Krishna Ghosh",
    //   "Anay Kulkarni",
    //   "Advik Bansal",
    //   "Hrishikesh Roy",
    //   "Rishaan Gupta",
    //   "Kiaan Kapoor",
    //   "Shaurya Sharma",
    //   "Aarush Pandey",
    //   "Vihaan Shetty",
    //   "Prithvi Deshmukh",
    //   "Rudra Roy",
    //   "Samar Thakur",
    //   "Darsh Dutta",
    //   "Aryan Kapoor",
    //   "Krish Garg",
    //   "Aaditya Verma",
    //   "Tanay Sehgal",
    //   "Atharva Sood",
    //   "Shreyas Dutta",
    //   "Shaurya Patel",
    //   "Andrew Fernandes",
    //   "John D'Souza",
    //   "Michael Pereira",
    //   "Peter Gomes",
    //   "Paul Rodrigues",
    //   "James Anthony",
    //   "David D'Cruz",
    //   "Philip Francis",
    //   "Mark Pinto",
    //   "Simon Fernandes",
    //   "Luke Almeida",
    //   "Matthew Lopes",
    //   "Peter Dias",
    //   "Thomas Sequeira",
    //   "Joseph Rebello",
    //   "Aaron Cohen",
    //   "Benjamin Levi",
    //   "David Goldstein",
    //   "Ethan Klein",
    //   "Jacob Katz",
    //   "Noah Rosen",
    //   "Isaac Bernstein",
    //   "Samuel Goldberg",
    //   "Adam Friedman",
    //   "Joshua Levy",
    //   "Elijah Green",
    //   "Caleb Silver",
    //   "Ezra Weiss",
    //   "Moses Rubin",
    //   "Nathaniel Adler",
    //   "Vikram Nair",
    //   "Ravi Kumar",
    //   "Manoj Iyer",
    //   "Ashwin Rao",
    //   "Karthik Venkatesh",
    //   "Rajesh Pillai",
    //   "Praveen Chandran",
    //   "Srinivas Raju",
    //   "Vijay Menon",
    //   "Suresh Babu",
    //   "Gopal Krishnan",
    //   "Mohan Swamy",
    //   "Sarath Nambiar",
    //   "Vignesh Patil",
    //   "Arjun Singh",
    //   "Jaspreet Singh",
    //   "Amrit Kaur",
    //   "Harpreet Singh",
    //   "Gurmeet Kaur",
    //   "Karanjeet Singh",
    //   "Manpreet Singh",
    //   "Simran Kaur",
    //   "Baldev Singh",
    //   "Jasleen Kaur",
    //   "Harbhajan Singh",
    //   "Amritpal Singh",
    //   "Rajveer Kaur",
    //   "Gurpreet Singh",
    //   "Navjot Kaur",
    //   "Andrew Fernandes",
    //   "John D'Souza",
    //   "Michael Pereira",
    //   "Peter Gomes",
    //   "Paul Rodrigues",
    //   "James Anthony",
    //   "David D'Cruz",
    //   "Philip Francis",
    //   "Mark Pinto",
    //   "Simon Fernandes",
    //   "Luke Almeida",
    //   "Matthew Lopes",
    //   "Peter Dias",
    //   "Thomas Sequeira",
    //   "Joseph Rebello",
    //   "Aaron Cohen",
    //   "Benjamin Levi",
    //   "David Goldstein",
    //   "Ethan Klein",
    //   "Jacob Katz",
    //   "Noah Rosen",
    //   "Isaac Bernstein",
    //   "Samuel Goldberg",
    //   "Adam Friedman",
    //   "Joshua Levy",
    //   "Elijah Green",
    //   "Caleb Silver",
    //   "Ezra Weiss",
    //   "Moses Rubin",
    //   "Nathaniel Adler",
    //   "Krishna Bhagat",
    //   "Mohan Satsangi",
    //   "Hari Bhavsar",
    //   "Dev Bhakta",
    //   "Shyam Bhaskar",
    //   "Raman Satsang",
    //   "Murari Bhatt",
    //   "Narayana Bhakta",
    //   "Girdhar Bhakt",
    //   "Shankar Bhavsar",
    //   "Radha Satsangi",
    //   "Madhav Bhakta",
    //   "Ram Satsang",
    //   "Govind Bhaskar",
    //   "Keshav Bhavsar",
    //   "Ranganathan Madhavan",
    //   "Rajagopalan Subramanian",
    //   "Srinivasan Narayanan",
    //   "Venkataraman Ramaswamy",
    //   "Krishnaswamy Ramanujan",
    //   "Viswanathan Anand",
    //   "Balasubramanian Rajendran",
    //   "Chandrasekaran Narasimhan",
    //   "Vijayaraghavan Seshadri",
    //   "Mahadevan Parthasarathy",
    //   "Ramakrishnan Sundararajan",
    //   "Jayaraman Vasudevan",
    //   "Krishnamurthy Swaminathan",
    //   "Thirumurugan Sivasubramanian",
    //   "Ravichandran Balakrishnan",
    //   "Sivaramakrishnan Ramachandran",
    //   "Narasimhaiah Venkateshwaran",
    //   "Chandrasekaran Venkatakrishnan",
    //   "Vidyasagar Balasubramanian",
    //   "Gopalan Sivasankar",
    //   "Venkatadri Lakshminarayanan",
    //   "Ranganayaki Rajasekaran",
    //   "Parthiban Viswanathan",
    //   "Rajasekaran Muthukrishnan",
    //   "Perumal Alagarsamy",
    //   "Radhakrishnan Jagannathan",
    //   "Janakiraman Ramachandran",
    //   "Vaidyanathan Srinivas",
    //   "Ramakrishnan Narayanaswamy",
    //   "Venkataraghavan Janakiraman",
    //   "Rajagopal Suryanarayanan",
    //   "Sundararajan Ramasubramanian",
    //   "Govindarajan Jayachandran",
    //   "Narasimhan Shankaranarayanan",
    //   "Balasubramanian Mahadevan",
    //   "Jagadeesan Chandrasekaran",
    //   "Srinivasan Venkataraman",
    //   "Thirunavukkarasu Duraisamy",
    //   "Arunachalam Ramanathan",
    //   "Shanmugam Parthasarathy",
    //   "Sivakumar Subramanian",
    //   "Krishnakumar Mahadevan",
    //   "Venkatapathy Ramaswamy",
    //   "Muthuraman Chidambaram",
    //   "Anantharaman Balachandran",
    //   "Natarajan Venkateswaran",
    //   "Sankaran Sivakumar",
    //   "Manickavasagam Subramanian",
    //   "Arunagiri Swaminathan",
    //   "Sivasubramanian Aravind",
    //   "Ahmed Khan",
    //   "Ayaan Sheikh",
    //   "Bilal Qureshi",
    //   "Farhan Malik",
    //   "Hassan Ali",
    //   "Ibrahim Siddiqui",
    //   "Imran Khan",
    //   "Junaid Hussain",
    //   "Khalid Rahman",
    //   "Mohammed Shah",
    //   "Nadeem Syed",
    //   "Omar Farooq",
    //   "Rafiq Ahmed",
    //   "Sami Shaikh",
    //   "Tariq Ansari",
    //   "Yusuf Patel",
    //   "Zaid Abbas",
    //   "Zain Hashmi",
    //   "Ali Mirza",
    //   "Saad Rizvi",
    //   "Arif Khan",
    //   "Asim Anwar",
    //   "Faizan Siddiqui",
    //   "Hasan Shaikh",
    //   "Irfan Malik",
    //   "Javed Khan",
    //   "Kasim Farooq",
    //   "Mohsin Qureshi",
    //   "Noman Ali",
    //   "Rizwan Ahmed",
    //   "Shoaib Ansari",
    //   "Taha Rahman",
    //   "Usman Shah",
    //   "Waseem Syed",
    //   "Yasir Sheikh",
    //   "Zubair Ahmed",
    //   "Amir Malik",
    //   "Aqib Khan",
    //   "Azhar Shaikh",
    //   "Bashir Hussain",
    //   "Danish Ali",
    //   "Ehsan Rahman",
    //   "Faisal Qureshi",
    //   "Gulzar Siddiqui",
    //   "Haroon Mirza",
    //   "Ilyas Sheikh",
    //   "Jawad Khan",
    //   "Khalil Malik",
    //   "Masood Shaikh",
    //   "Nabeel Hussain",
    //   "Qasim Ahmed",
    //   "Rashid Khan",
    //   "Salman Rahman",
    //   "Sohail Shaikh",
    //   "Tanveer Ali",
    //   "Waqar Siddiqui",
    //   "Yamin Qureshi",
    //   "Zakir Syed",
    //   "Arshad Malik",
    //   "Babar Khan",
    //   "Fahad Sheikh",
    //   "Hammad Ali",
    //   "Kamran Rahman",
    //   "Luqman Ahmed",
    //   "Nisar Qureshi",
    //   "Rameez Siddiqui",
    //   "Saeed Shaikh",
    //   "Sarfraz Hussain",
    //   "Tabish Khan",
    //   "Wajid Ahmed",
    //   "Yunus Malik",
    //   "Zeeshan Sheikh",
    //   "Adeel Ali",
    //   "Amin Rahman",
    //   "Anas Qureshi",
    //   "Ayub Siddiqui",
    //   "Basit Shaikh",
    //   "Feroz Hussain",
    //   "Hamza Khan",
    //   "Kazim Ahmed",
    //   "Mansoor Rahman",
    //   "Murtaza Shaikh",
    //   "Nazim Qureshi",
    //   "Rahim Siddiqui",
    //   "Shahid Ali",
    //   "Talha Sheikh",
    //   "Uzair Ahmed",
    //   "Zubair Malik",
    //   "Aarav Sharma",
    //   "Aryan Verma",
    //   "Vedant Singh",
    //   "Aditya Rao",
    //   "Aniruddh Reddy",
    //   "Bharat Patel",
    //   "Chaitanya Joshi",
    //   "Dhruv Iyer",
    //   "Eshan Kapoor",
    //   "Gautam Bhardwaj",
    //   "Harsh Vardhan",
    //   "Ishaan Mehta",
    //   "Jayant Nair",
    //   "Kunal Swamy",
    //   "Lakshman Menon",
    //   "Madhav Kulkarni",
    //   "Narayana Bhat",
    //   "Omkar Rajan",
    //   "Pranav Deshmukh",
    //   "Raghav Naidu",
    //   "Siddharth Krishnan",
    //   "Tanmay Pillai",
    //   "Udit Ramachandran",
    //   "Vivek Nambiar",
    //   "Yashwant Iyengar",
    //   "Vishnu Rao",
    //   "Kailash Raju",
    //   "Surya Patel",
    //   "Tejas Sundararajan",
    //   "Ajit Chakravarthy",
    //   "Darsh Venkatesh",
    //   "Girish Ravi",
    //   "Hemant Vaidyanathan",
    //   "Indra Mohan",
    //   "Jatin Ramaswamy",
    //   "Karan Balakrishnan",
    //   "Lokesh Janardhan",
    //   "Manish Gopal",
    //   "Naveen Shivaram",
    //   "Om Prakash",
    //   "Pavan Sundaram",
    //   "Rajiv Ananth",
    //   "Sarvesh Vasishta",
    //   "Tarun Narayanan",
    //   "Uday Keshavan",
    //   "Vikas Janaki",
    //   "Yugesh Bhaskaran",
    //   "Suhas Devi",
    //   "Rajat Shrivastava",
    //   "Rohit Acharya",
    //   "Ashwin Sharma",
    //   "Dinesh Deshmukh",
    //   "Govind Rao",
    //   "Harshal Iyengar",
    //   "Jayesh Seshadri",
    //   "Keshav Subramanian",
    //   "Mohan Yadav",
    //   "Naveen Chandran",
    //   "Rajesh Ramanujan",
    //   "Suresh Venkataraman",
    //   "Arun Kumar",
    //   "Bhuvanesh Chandrasekar",
    //   "Chandan Kumar",
    //   "Dhanush Ramachandra",
    //   "Eshwar Shastri",
    //   "Gaurav Adhikari",
    //   "Harit Desai",
    //   "Jayanth Rao",
    //   "Kishore Prasad",
    //   "Madhur Desai",
    //   "Narayan Iyer",
    //   "Omkar Nambiar",
    //   "Pushkar Adhikari",
    //   "Ramesh Bhaskar",
    //   "Sarvesh Swamy",
    //   "Shashank Menon",
    //   "Shivansh Venkatesh",
    //   "Siddhanth Sharma",
    //   "Sudhanshu Nair",
    //   "Tarang Iyengar",
    //   "Utkarsh Dutta",
    //   "Utsav Raju",
    //   "Vachan Shetty",
    //   "Vikrant Reddy",
    //   "Vimal Rao",
    //   "Abhishek Kumar",
    //   "Akash Kumar",
    //   "Ankit Kumar",
    //   "Arjun Kumar",
    //   "Ashish Kumar",
    //   "Biswajit Kumar",
    //   "Deepak Kumar",
    //   "Gaurav Kumar",
    //   "Harsh Kumar",
    //   "Jaidev Kumar",
    //   "Jay Kumar",
    //   "Kaushik Kumar",
    //   "Kunal Kumar",
    //   "Lakshmi Kumar",
    //   "Manoj Kumar",
    //   "Nikhil Kumar",
    //   "Prashant Kumar",
    //   "Rahul Kumar",
    //   "Ravindra Kumar",
    //   "Rohit Kumar",
    //   "Sanjay Kumar",
    //   "Shaurya Kumar",
    //   "Shreyas Kumar",
    //   "Siddharth Kumar",
    //   "Suraj Kumar",
    //   "Vijay Kumar",
    //   "Vishal Kumar",
    //   "Abhishek Singh",
    //   "Akash Singh",
    //   "Ankit Singh",
    //   "Arjun Singh",
    //   "Ashish Singh",
    //   "Biswajit Singh",
    //   "Deepak Singh",
    //   "Gaurav Singh",
    //   "Harsh Singh",
    //   "Jaidev Singh",
    //   "Jay Singh",
    //   "Kaushik Singh",
    //   "Kunal Singh",
    //   "Lakshmi Singh",
    //   "Manoj Singh",
    //   "Nikhil Singh",
    //   "Prashant Singh",
    //   "Rahul Singh",
    //   "Ravindra Singh",
    //   "Rohit Singh",
    //   "Sanjay Singh",
    //   "Shaurya Singh",
    //   "Shreyas Singh",
    //   "Siddharth Singh",
    //   "Suraj Singh",
    //   "Vijay Singh",
    //   "Vishal Singh",
    //   "Abhishek Yadav",
    //   "Akash Yadav",
    //   "Ankit Yadav",
    //   "Arjun Yadav",
    //   "Ashish Yadav",
    //   "Biswajit Yadav",
    //   "Deepak Yadav",
    //   "Gaurav Yadav",
    //   "Harsh Yadav",
    //   "Jaidev Yadav",
    //   "Jay Yadav",
    //   "Kaushik Yadav",
    //   "Kunal Yadav",
    //   "Lakshmi Yadav",
    //   "Manoj Yadav",
    //   "Nikhil Yadav",
    //   "Prashant Yadav",
    //   "Rahul Yadav",
    //   "Ravindra Yadav",
    //   "Rohit Yadav",
    //   "Sanjay Yadav",
    //   "Shaurya Yadav",
    //   "Shreyas Yadav",
    //   "Siddharth Yadav",
    //   "Suraj Yadav",
    //   "Vijay Yadav",
    //   "Vishal Yadav",
    //   "Abhishek Sharma",
    //   "Akash Sharma",
    //   "Ankit Sharma",
    //   "Anik Sen",
    //   "Arjun Biswas",
    //   "Ritwik Das",
    //   "Anirban Mukherjee",
    //   "Debjit Roy",
    //   "Subhajit Chatterjee",
    //   "Partha Banerjee",
    //   "Amitava Bhattacharya",
    //   "Koushik Dutta",
    //   "Subrata Sengupta",
    //   "Soumya Chakraborty",
    //   "Arindam Ghosh",
    //   "Debashish Saha",
    //   "Dipankar Majumdar",
    //   "Gautam Basu",
    //   "Sujit Mondal",
    //   "Anindya Bhowmik",
    //   "Pradip Chandra",
    //   "Rupam Saha",
    //   "Tamal Pal",
    //   "Sayan Ghosh",
    //   "Niladri Dutta",
    //   "Swapan Ghosh",
    //   "Sudip Sarkar",
    //   "Arup Ray",
    //   "Saikat Dasgupta",
    //   "Bijoy Choudhury",
    //   "Prosenjit Sen",
    //   "Satyajit Chakraborty",
    //   "Ananda Mukherjee",
    //   "Ujjal Bhattacharjee",
    //   "Samrat Bose",
    //   "Arghya Sinha",
    //   "Manoj Bhattacharya",
    //   "Dipayan Debnath",
    //   "Barun Datta",
    //   "Bikash Mitra",
    //   "Anupam Ghoshal",
    //   "Sujay Chatterjee",
    //   "Supriyo Choudhury",
    //   "Aniruddha Mukhopadhyay",
    //   "Sougata Dey",
    //   "Sumanta Adhikary",
    //   "Sandip Nandi",
    //   "Sourav Roy",
    //   "Abhijit Ghosh",
    //   "Saptarshi Paul",
    //   "Sayantan Naskar",
    //   "Joydeep Mitra",
    //   "Arko Majumdar",
    //   "Sudipta Banik",
    //   "Partha Basu",
    //   "Tapas Das",
    //   "Mrinmoy Chatterjee",
    //   "Sounak Chakraborty",
    //   "Tushar Das",
    //   "Nilanjan Sarkar",
    //   "Saikat Mitra",
    //   "Soumen Bhattacharya",
    //   "Souvik Roy",
    //   "Nirmalya Ghosh",
    //   "Arka Dey",
    //   "Sumit Mondal",
    //   "Rajarshi Chatterjee",
    //   "Arnav Mukherjee",
    //   "Samir Sen",
    //   "Prasenjit Chakraborty",
    //   "Subham Bhattacharya",
    //   "Bishal Dutta",
    //   "Tanmay Ghosh",
    //   "Animesh Bhattacharya",
    //   "Dipankar Choudhury",
    //   "Sidhartha Basu",
    //   "Suvro Banik",
    //   "Avik Majumdar",
    //   "Amitava Mukherjee",
    //   "Rudra Roy",
    //   "Subhrajit Ghoshal",
    //   "Anubhav Sen",
    //   "Prasun Bhattacharya",
    //   "Suman Saha",
    //   "Kunal Ghosh",
    //   "Tapas Pal",
    //   "Arin Datta",
    //   "Gautam Chakraborty",
    //   "Rahul Sengupta",
    //   "Arindam Basu",
    //   "Tanmoy Das",
    //   "Avijit Choudhury",
    //   "Swagata Bhowmik",
    //   "Asim Dey",
    //   "Rana Mukherjee",
    //   "Somnath Basak",
    //   "Anup Chakraborty",
    //   "Sajal Sarkar",
    //   "Ananya Iyer",
    //   "Keerthana Reddy",
    //   "Lakshmi Menon",
    //   "Deepa Nair",
    //   "Aishwarya Rao",
    //   "Jasleen Kaur",
    //   "Simran Kaur",
    //   "Harpreet Kaur",
    //   "Gurleen Kaur",
    //   "Navneet Kaur",
    //   "Anna D'Souza",
    //   "Maria Fernandes",
    //   "Grace Pereira",
    //   "Sophia Gomes",
    //   "Isabella Rodrigues",
    //   "Ariel Cohen",
    //   "Leah Levi",
    //   "Miriam Goldstein",
    //   "Naomi Klein",
    //   "Rebecca Katz",
    //   "Radha Bhagat",
    //   "Meera Satsangi",
    //   "Krishna Bhavsar",
    //   "Bhakti Bhakta",
    //   "Gopi Bhaskar",
    //   "Ananya Sen",
    //   "Ishita Mukherjee",
    //   "Ritika Roy",
    //   "Debanjana Chatterjee",
    //   "Shraboni Das",
    //   "Aisha Khan",
    //   "Fatima Sheikh",
    //   "Zara Qureshi",
    //   "Nadia Malik",
    //   "Sana Ali",
    //   "Aaradhya Sharma",
    //   "Veda Verma",
    //   "Devika Singh",
    //   "Bhavana Rao",
    //   "Saraswati Reddy"
    // ];
    // final itemIds = List.generate(10, (index) => index + 1);
    // final materialFamily = [1, 2, 3];

    final mortgageMaterials = [
      'Ring',
      'Anklet',
      'Bracelet',
      'Armlet',
      'Chain',
      'Ear-Ring',
      'Head-Locket',
      'Medal',
      'Necklace',
      'Locket',
      'Neck band',
    ];
    final familyRelations = ['Husband', 'Father', 'Wife'];
    final batch = db.batch();
    batch.execute(
      'CREATE TABLE IF NOT EXISTS mortgageMaterials(id INTEGER PRIMARY KEY, name TEXT UNIQUE, isAddedByUser INTEGER)',
    );
    batch.execute(
      'CREATE TABLE IF NOT EXISTS familyRelations(id INTEGER PRIMARY KEY, name TEXT UNIQUE, isAddedByUser INTEGER)',
    );
    batch.execute(
      'CREATE TABLE IF NOT EXISTS weightUnits(id INTEGER PRIMARY KEY, name TEXT NOT NULL, symbol TEXT NOT NULL UNIQUE, isAddedByUser INTEGER NOT NULL DEFAULT 0)',
    );
    batch.execute(
      '''CREATE TABLE IF NOT EXISTS loans(id INTEGER PRIMARY KEY, depositorName TEXT, phoneNumber TEXT, email TEXT,
           relativeName TEXT, address TEXT, loanAmount REAL, interestRate REAL,weight REAL, weightUnit TEXT NOT NULL DEFAULT 'g', interestType INTEGER,
           interestFrequency INTEGER, mortgageTermYears INTEGER NOT NULL DEFAULT 5,
           lockInDays INTEGER NOT NULL DEFAULT 0,
           earlyRedemptionCharge REAL NOT NULL DEFAULT 0, additionalDetails TEXT,
           termsAndConditions TEXT NOT NULL DEFAULT '',
           dateCreated TEXT, dateFinished TEXT, completedBy TEXT NOT NULL DEFAULT '', settlementAmount REAL,
           completionReference TEXT NOT NULL DEFAULT '', completionNotes TEXT NOT NULL DEFAULT '',
           familyRelationId INTEGER, mortgageMaterialId INTEGER,
           FOREIGN KEY (familyRelationId) REFERENCES familyRelations (id),
           FOREIGN KEY (mortgageMaterialId) REFERENCES mortgageMaterials (id),
           UNIQUE(depositorName, relativeName, address, loanAmount, familyRelationId) )''',
    );
    batch.execute(
      '''CREATE TABLE IF NOT EXISTS loanChanges(id INTEGER PRIMARY KEY, loanId INTEGER NOT NULL,
           description TEXT NOT NULL, createdAt TEXT NOT NULL,
           FOREIGN KEY (loanId) REFERENCES loans (id))''',
    );

    for (final mortgageMaterial in mortgageMaterials) {
      batch.insert(MortgageMaterial.tableName, {
        MortgageMaterialFields.name: mortgageMaterial,
        MortgageMaterialFields.isAddedByUser: 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final familyRelation in familyRelations) {
      batch.insert(FamilyRelation.tableName, {
        FamilyRelationFields.name: familyRelation,
        FamilyRelationFields.isAddedByUser: 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    for (final unit in const [
      WeightUnit(name: 'Gram', symbol: 'g'),
      WeightUnit(name: 'Kilogram', symbol: 'kg'),
      WeightUnit(name: 'Milligram', symbol: 'mg'),
      WeightUnit(name: 'Tola', symbol: 'tola'),
    ]) {
      batch.insert(
        WeightUnit.tableName,
        unit.toJson(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // for (final name in indianBoysNames) {
    //   batch.insert(Mortgage.tableName, {
    //     MortgageFields.depositorName: name,
    //     MortgageFields.relativeName: faker.person.name(),
    //     MortgageFields.address:
    //         '${faker.address.streetAddress()}, ${faker.address.city()}, ${faker.address.state()}, ${faker.address.zipCode()}, ${faker.address.country()}',
    //     MortgageFields.loanAmount: 100 * random.decimal(min: 100, scale: 10),
    //     MortgageFields.interestRate: random.decimal(min: 1),
    //     MortgageFields.weight: random.decimal(),
    //     MortgageFields.interestType: random.element(InterestType.values).index,
    //     MortgageFields.compoundingFrequency:
    //         random.element(CompoundingFrequency.values).index,
    //     MortgageFields.additionalDetails: faker.company.name(),
    //     MortgageFields.dateCreated: DateTime.now().toString(),
    //     MortgageFields.itemId: random.element(itemIds),
    //     MortgageFields.familyRelationId: random.element(materialFamily),
    //     MortgageFields.mortgageMaterialId: random.element(materialFamily)
    //   });
    // }

    await batch.commit();
    FastDB.putIsTableCreated(true);
    await FastDB.flush();
  }

  /// Merges user data from [source] into the live database.
  ///
  /// Validate before writing, then merge all SQL records in one transaction.
  /// Ambiguous legacy identity matches fail instead of discarding differences.
  /// [targetDatabase] permits validation against a staging database and tests.
  /// This transaction does not include auxiliary settings files.
  static Future<void> restoreTables(
    Database source, {
    Database? targetDatabase,
  }) async {
    final version = await source.getVersion();
    if (version < 1 || version > 7) {
      throw const FormatException('Unsupported backup database version.');
    }
    final integrity = await source.rawQuery('PRAGMA integrity_check');
    if (integrity.length != 1 || integrity.single.values.single != 'ok') {
      throw const FormatException(
        'The backup database failed its integrity check.',
      );
    }
    final sourceTables =
        (await source.rawQuery(
              "SELECT name FROM sqlite_master WHERE type = 'table'",
            ))
            .map((row) => row['name'])
            .whereType<String>()
            .map((name) => name.toLowerCase())
            .toSet();
    final requiredTables = {
      FamilyRelation.tableName,
      MortgageMaterial.tableName,
      Loan.tableName,
    }.map((name) => name.toLowerCase()).toSet();
    if (!sourceTables.containsAll(requiredTables)) {
      throw const FormatException(
        'The backup database is missing required tables.',
      );
    }

    final List<Map<String, dynamic>> familyRelations = await source.query(
      FamilyRelation.tableName,
    );
    final List<Map<String, dynamic>> mortgageMaterials = await source.query(
      MortgageMaterial.tableName,
    );
    final List<Map<String, dynamic>> weightUnits =
        sourceTables.contains(WeightUnit.tableName.toLowerCase())
        ? await source.query(WeightUnit.tableName)
        : const [];
    final List<Map<String, dynamic>> loans = await source.query(Loan.tableName);
    final List<Map<String, dynamic>> loanChanges =
        sourceTables.contains(LoanChange.tableName.toLowerCase())
        ? await source.query(LoanChange.tableName)
        : const [];

    final sourceLoanIds = loans.map((row) => row[LoanFields.id]).toSet();
    for (final change in loanChanges) {
      if (!sourceLoanIds.contains(change[LoanChangeFields.loanId])) {
        throw const FormatException(
          'A backup audit event references a missing loan.',
        );
      }
    }
    for (final row in loans) {
      for (final field in [
        LoanFields.loanAmount,
        LoanFields.interestRate,
        LoanFields.weight,
        LoanFields.earlyRedemptionCharge,
        LoanFields.settlementAmount,
      ]) {
        final value = row[field];
        if (value != null && (value is! num || !value.isFinite || value < 0)) {
          throw FormatException('Invalid backup financial field: $field.');
        }
      }
      if (row[LoanFields.loanAmount] == null ||
          row[LoanFields.dateCreated] == null) {
        throw const FormatException(
          'A backup loan is missing required financial data.',
        );
      }
      if (DateTime.tryParse(row[LoanFields.dateCreated].toString()) == null ||
          (row[LoanFields.dateFinished] != null &&
              DateTime.tryParse(row[LoanFields.dateFinished].toString()) ==
                  null)) {
        throw const FormatException('A backup loan has an invalid date.');
      }
    }

    final target = targetDatabase ?? await instance.database;
    await target.transaction((transaction) async {
      final relationIds = <int, int>{};
      for (final familyRelation in familyRelations) {
        final sourceId = familyRelation[FamilyRelationFields.id] as int;
        final name = familyRelation[FamilyRelationFields.name] as String;
        final existing = await transaction.query(
          FamilyRelation.tableName,
          columns: [FamilyRelationFields.id],
          where: 'LOWER(${FamilyRelationFields.name}) = LOWER(?)',
          whereArgs: [name],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          relationIds[sourceId] =
              existing.first[FamilyRelationFields.id] as int;
        } else {
          final values = Map<String, Object?>.from(familyRelation)
            ..remove(FamilyRelationFields.id);
          relationIds[sourceId] = await transaction.insert(
            FamilyRelation.tableName,
            values,
          );
        }
      }

      final materialIds = <int, int>{};
      for (final mortgageMaterial in mortgageMaterials) {
        final sourceId = mortgageMaterial[MortgageMaterialFields.id] as int;
        final name = mortgageMaterial[MortgageMaterialFields.name] as String;
        final existing = await transaction.query(
          MortgageMaterial.tableName,
          columns: [MortgageMaterialFields.id],
          where: 'LOWER(${MortgageMaterialFields.name}) = LOWER(?)',
          whereArgs: [name],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          materialIds[sourceId] =
              existing.first[MortgageMaterialFields.id] as int;
        } else {
          final values = Map<String, Object?>.from(mortgageMaterial)
            ..remove(MortgageMaterialFields.id);
          materialIds[sourceId] = await transaction.insert(
            MortgageMaterial.tableName,
            values,
          );
        }
      }

      for (final weightUnit in weightUnits) {
        final symbol = weightUnit[WeightUnitFields.symbol] as String;
        final existing = await transaction.query(
          WeightUnit.tableName,
          columns: [WeightUnitFields.id],
          where: 'LOWER(${WeightUnitFields.symbol}) = LOWER(?)',
          whereArgs: [symbol],
          limit: 1,
        );
        if (existing.isEmpty) {
          final values = Map<String, Object?>.from(weightUnit)
            ..remove(WeightUnitFields.id);
          await transaction.insert(WeightUnit.tableName, values);
        }
      }

      final loanIds = <int, int>{};
      for (final sourceLoan in loans) {
        final sourceId = sourceLoan[LoanFields.id] as int;
        final sourceRelationId = sourceLoan[LoanFields.familyRelationId] as int;
        final sourceMaterialId =
            sourceLoan[LoanFields.mortgageMaterialId] as int;
        final relationId = relationIds[sourceRelationId];
        final materialId = materialIds[sourceMaterialId];
        if (relationId == null || materialId == null) {
          throw const FormatException(
            'A backup loan references missing relation or material data.',
          );
        }

        final existing = await transaction.query(
          Loan.tableName,
          where:
              '${LoanFields.depositorName} = ? AND '
              '${LoanFields.relativeName} = ? AND '
              '${LoanFields.address} = ? AND '
              '${LoanFields.loanAmount} = ? AND '
              '${LoanFields.familyRelationId} = ?',
          whereArgs: [
            sourceLoan[LoanFields.depositorName],
            sourceLoan[LoanFields.relativeName],
            sourceLoan[LoanFields.address],
            sourceLoan[LoanFields.loanAmount],
            relationId,
          ],
          limit: 1,
        );
        final values = Map<String, Object?>.from(sourceLoan)
          ..remove(LoanFields.id)
          ..[LoanFields.familyRelationId] = relationId
          ..[LoanFields.mortgageMaterialId] = materialId;
        if (existing.isNotEmpty) {
          // Legacy records have no stable cross-device identity. Never treat
          // matching names and principal as permission to discard other data.
          final targetLoan = existing.single;
          if (values.entries.any(
            (entry) => targetLoan[entry.key] != entry.value,
          )) {
            throw const FormatException(
              'The backup contains a loan that conflicts with a local record. '
              'Restore into a separate database for reconciliation.',
            );
          }
          loanIds[sourceId] = existing.first[LoanFields.id] as int;
          continue;
        }

        loanIds[sourceId] = await transaction.insert(Loan.tableName, values);
        final persisted = (await transaction.query(
          Loan.tableName,
          where: '${LoanFields.id} = ?',
          whereArgs: [loanIds[sourceId]],
        )).single;
        if (values.entries.any(
          (entry) => persisted[entry.key] != entry.value,
        )) {
          throw const FormatException(
            'Restored loan values failed reconciliation.',
          );
        }
      }

      for (final sourceChange in loanChanges) {
        final sourceLoanId = sourceChange[LoanChangeFields.loanId] as int;
        final loanId = loanIds[sourceLoanId];
        if (loanId == null) {
          throw const FormatException(
            'A backup audit event could not be mapped.',
          );
        }
        final description = sourceChange[LoanChangeFields.description];
        final createdAt = sourceChange[LoanChangeFields.createdAt];
        final existing = await transaction.query(
          LoanChange.tableName,
          columns: [LoanChangeFields.id],
          where:
              '${LoanChangeFields.loanId} = ? AND '
              '${LoanChangeFields.description} = ? AND '
              '${LoanChangeFields.createdAt} = ?',
          whereArgs: [loanId, description, createdAt],
          limit: 1,
        );
        if (existing.isEmpty) {
          final values = Map<String, Object?>.from(sourceChange)
            ..remove(LoanChangeFields.id)
            ..[LoanChangeFields.loanId] = loanId;
          await transaction.insert(LoanChange.tableName, values);
        }
      }
    });
  }

  Future close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
}
