import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;
import 'package:path/path.dart' as p;

// Moor works by source gen. This file will all the generated code.
part 'moor_database.g.dart';

// The name of the database table is "tasks"
// By default, the name of the generated data class will be "Task" (without "s")
// (Annotation @DataClassName) => The default data class name "Tasks" would now be "SomeOtherNameIfYouWant"
// @DataClassName('SomeOtherNameIfYouWant')
class Tasks extends Table {
  // autoIncrement automatically sets this to be the primary key
  IntColumn get id => integer().autoIncrement()();
  // add nullable tagName
  TextColumn get tagName =>
      text().nullable().customConstraint('NULL REFERENCES tags(name)')();
  // If the length constraint is not fulfilled, the Task will not
  // be inserted into the database and an exception will be thrown.
  TextColumn get name => text().withLength(min: 1, max: 50)();
  // DateTime is not natively supported by SQLite
  // Moor converts it to & from UNIX seconds
  DateTimeColumn get dueDate => dateTime().nullable()();
  // Booleans are not supported as well, Moor converts them to integers
  // Simple default values are specified as Constants
  BoolColumn get completed => boolean().withDefault(Constant(false))();
}

// tambahin table Tags
class Tags extends Table {
  TextColumn get name => text().withLength(min: 1, max: 10)();
  IntColumn get color => integer()();

  // Making name as the primary key of a tag requires names to be unique
  @override
  Set<Column> get primaryKey => {name};
}

// Task jadi sepaket dengan tag
// We have to group tasks with tags manually.
// This class will be used for the table join.
class TaskWithTag {
  final Task task;
  final Tag? tag;

  TaskWithTag({
    required this.task,
    this.tag,
  });
}



// This annotation tells the code generator which tables this DB works with
// update table dan dao yang dipakai
@DriftDatabase(tables: [Tasks, Tags], daos: [TaskDao, TagDao])
// _$AppDatabase is the name of the generated class
class AppDatabase extends _$AppDatabase {
  AppDatabase()
      // Specify the location of the database file
      : super(
      LazyDatabase(() async {
        final dbFolder = await getDatabasesPath();
        final file = File(p.join(dbFolder, 'db.sqlite'));
        return NativeDatabase(file,logStatements: true);
      })

      // FlutterQueryExecutor.inDatabaseFolder(
      //     path: 'db.sqlite',
      //     // Good for debugging - prints SQL in the console
      //     logStatements: true,
      //   )

  );



  // Bump this when changing tables and columns.
  // Migrations will be covered in the next part.
  @override
  int get schemaVersion => 2;

  // sebenarnya untuk update data, migrasi, tapi tadi ada eror jadi data sebelumnya kehapus hehe
  @override
  MigrationStrategy get migration => MigrationStrategy(
          // Runs if the database has already been opened on the device with a lower version
          onUpgrade: (migrator, from, to) async {
        if (from == 1) {
          await migrator.addColumn(tasks, tasks.tagName);
          await migrator.createTable(tags);
        }
      },
          // This migration property ties in nicely with the foreign key we've added previously.
          // It turns out that foreign keys are actually not enabled by default in SQLite - we have to
          // enable them ourselves with a custom statement.
          // We want to run this statement before any other queries are run to
          // prevent the chance of  "unchecked data" from entering the database.
          // This is a perfect use-case for the beforeOpen callback.
          // Runs after all the migrations but BEFORE any queries have a chance to execute
          beforeOpen: (details) async {
        // ini lumayan beda dari Reso Coder, tapi kyknya ini caranya
        await customStatement('PRAGMA foreign_keys = ON');
      });
}

// Denote which tables this DAO can access
@DriftAccessor(tables: [Tasks, Tags])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  final AppDatabase db;

  // Called by the AppDatabase class
  TaskDao(this.db) : super(db);

  // Ganti return type
  // Return TaskWithTag now
  Stream<List<TaskWithTag>> watchAllTasks() {
    // Wrap the whole select statement in parenthesis
    var val = (select(tasks)
    // Statements like orderBy and where return void => the need to use a cascading ".." operator
      ..orderBy(
        ([
          // Primary sorting by due date
              (t) =>
              OrderingTerm(expression: t.dueDate, mode: OrderingMode.desc),
          // Secondary alphabetical sorting
              (t) => OrderingTerm(expression: t.name),
        ]),
      ))
    // TODO nanti perdalami lagi soal join di moor ini
    // As opposed to orderBy or where, join returns a value. This is what we want to watch/get.
        .join(
      [
        // Join all the tasks with their tags.
        // It's important that we use equalsExp and not just equals.
        // This way, we can join using all tag names in the tasks table, not just a specific one.
        leftOuterJoin(tags, tags.name.equalsExp(tasks.tagName)),
      ],
    )
    // watch the whole select statement including the join
        .watch()
    // Watching a join gets us a Stream of List<TypedResult>
    // Mapping each List<TypedResult> emitted by the Stream to a List<TaskWithTag>
        .map(
          (rows) => rows.map(
            (row) {
          return TaskWithTag(
            task: row.readTable(tasks),
            // In dia penyebab masalah, tutorial dibuat ketika null safety belum ada di dart
            tag: row.readTableOrNull(tags),
          );
        },
      ).toList(),
    );
    print("This is the list boy: ${val.toList().toString()}");
    return val;
  }

  Stream<List<TaskWithTag>> watchCompletedTasks() {
    // where returns void, need to use the cascading operator
    return (select(tasks)
          ..orderBy(
            ([
              // Primary sorting by due date
              (t) =>
                  OrderingTerm(expression: t.dueDate, mode: OrderingMode.desc),
              // Secondary alphabetical sorting
              (t) => OrderingTerm(expression: t.name),
            ]),
          )
          ..where((t) => t.completed.equals(true)))
        .join(
          [
            // Join all the tasks with their tags.
            // It's important that we use equalsExp and not just equals.
            // This way, we can join using all tag names in the tasks table, not just a specific one.
            leftOuterJoin(tags, tags.name.equalsExp(tasks.tagName)),
          ],
        )
        .watch()
        .map(
          (rows) => rows.map(
            (row) {
              return TaskWithTag(
                task: row.readTable(tasks),
                tag: row.readTable(tags),
              );
            },
          ).toList(),
        );
  }

  Future insertTask(Insertable<Task> task) => into(tasks).insert(task);

  // Updates a Task with a matching primary key
  Future updateTask(Insertable<Task> task) => update(tasks).replace(task);

  Future deleteTask(Insertable<Task> task) => delete(tasks).delete(task);
}

@DriftAccessor(tables: [Tags])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  final AppDatabase db;

  TagDao(this.db) : super(db);

  Stream<List<Tag>> watchTags() => select(tags).watch();
  Future insertTag(Insertable<Tag> tag) => into(tags).insert(tag);
}
