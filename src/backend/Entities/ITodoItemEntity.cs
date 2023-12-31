using System;
using System.Threading.Tasks;
using backend.Models;

namespace backend.Entities;

public interface ITodoItemEntity
{
    Task Create(TodoItem todoItem);

    Task Sync();

    Task Delete();
}