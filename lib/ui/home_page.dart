import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:task_list_app/widget/new_tag_input_widget.dart';
import 'package:task_list_app/widget/new_task_input_widget.dart';

import '../data/moor_database.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool showCompleted = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Tasks'),
          // TODO nanti terapkan dengan TaskWithTag
          actions: <Widget>[
            _buildCompletedOnlySwitch(),
          ],
        ),
        body: Column(
          children: <Widget>[
            Expanded(child: _buildTaskList(context)),
            NewTaskInput(),
            // Ini untuk create Tag
            NewTagInput(),
          ],
        ));
  }

  // TODO nanti terapkan dengan TaskWithTag

  Row _buildCompletedOnlySwitch() {
    return Row(
      children: <Widget>[
        const Text('Completed only'),
        Switch(
          value: showCompleted,
          activeColor: Colors.white,
          onChanged: (newValue) {
            setState(() {
              showCompleted = newValue;
            });
          },
        ),
      ],
    );
  }

  StreamBuilder<List<TaskWithTag>> _buildTaskList(BuildContext context) {
    final dao = Provider.of<TaskDao>(context);
    return StreamBuilder(
      stream:
      // TODO nanti terapkan dengan TaskWithTag
      showCompleted ?
      dao.watchCompletedTasks() :
      dao.watchAllTasks(),
      builder: (context, AsyncSnapshot<List<TaskWithTag>> snapshot) {
        final tasks = snapshot.data ?? [];

        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (_, index) {
            final itemTask = tasks[index];
            return _buildListItem(itemTask, dao);
          },
        );
      },
    );
  }

  Column _buildTag(Tag? tag) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (tag != null) ...[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(tag.color),
            ),
          ),
          Text(
            tag.name,
            style: TextStyle(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildListItem(TaskWithTag item, TaskDao dao) {
    return Slidable(
      actionPane: SlidableDrawerActionPane(),
      secondaryActions: <Widget>[
        IconSlideAction(
          caption: 'Delete',
          color: Colors.red,
          icon: Icons.delete,
          onTap: () => dao.deleteTask(item.task),
        )
      ],
      child: CheckboxListTile(
        title: Text(item.task.name),
        subtitle: Text(item.task.dueDate?.toString() ?? 'No date'),
        secondary: _buildTag(item.tag),
        value: item.task.completed,
        onChanged: (newValue) {
          dao.updateTask(item.task.copyWith(completed: newValue));
        },
      ),
    );
  }
}